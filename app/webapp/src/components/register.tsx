import {FormEvent, Dispatch} from "react";
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import Container from 'react-bootstrap/Container';
import Alert from 'react-bootstrap/Alert';
import { ErrorCode, Api, Error, ParameterError } from "../api";
import { ChangeEvent,useState } from 'react'
import { useNavigate, useSearchParams } from "react-router";
import { Link } from "react-router";

export default function Register({api}: {api: Api}) {
  const navigate = useNavigate();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");

  const [staySignedIn, setStaySignedIn] = useState(false);
  const [feedback, setFeedback] = useState(null);
  const [nameFeedback, setNameFeedback] = useState(null);
  const [emailFeedback, setEmailFeedback] = useState(null);
  const [passwordFeedback, setPasswordFeedback] = useState(null);

  let [parameters, _] = useSearchParams();
  const redirectTo = parameters.get("redirectTo");

  const parameterFeedbacks : Record<string, Dispatch<{type: string, content: string, alert: string}>> = {
    "name": setNameFeedback,
    "email": setEmailFeedback,
    "password": setPasswordFeedback,
  };

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    
    api.register(email, name, password, staySignedIn).then(_ => {
      setFeedback({type: "valid", content: "Successfully sign-in", alert: "success"});
      setTimeout(() => { navigate(redirectTo || "/") }, 1000)
    }).catch((error: Error) => {
      if (error.code === ErrorCode.BadParameter) {
        (error as ParameterError).parameters.forEach(parameter => {
          (parameterFeedbacks[parameter.name] || setFeedback)({type: "invalid", content: parameter.issue, alert: "warning"});
        });
      } else {
        setFeedback({type: "invalid", content: error.message || error.error, alert: "danger"});
      }
    })
    return false;
  }

  function onEmailInput(event: ChangeEvent<HTMLInputElement>) {
    setEmail(event.target.value);
  }

  function onNameInput(event: ChangeEvent<HTMLInputElement>) {
    setName(event.target.value);
  }

  function onPasswordInput(event: ChangeEvent<HTMLInputElement>) {
    setPassword(event.target.value);
  }

  function onStaySingedInput(event: ChangeEvent<HTMLInputElement>) {
    setStaySignedIn(event.target.checked);
  }

  return (
    <Container className="flex-flex">
      <div className="flex-flex center-center">
        <Form onSubmit={onSubmit}>
          <h3 className="pb-3">Sign-up</h3>
    
          <Form.Group className="mb-3">
            <Form.Label>Email address</Form.Label>
            {/* Not using type="email" because something then mess up the form by adding random validation popup */}
            <Form.Control type="text" placeholder="Enter email" value={email} onChange={onEmailInput} isInvalid={emailFeedback?.type == "invalid"}/>
            <Form.Text className="text-muted">
              We'll never share your email with anyone else.
            </Form.Text>
            <Form.Control.Feedback type="invalid">
              {emailFeedback?.content}
            </Form.Control.Feedback>
          </Form.Group>

          <Form.Group className="mb-3">
            <Form.Label>Display name</Form.Label>
            <Form.Control type="text" placeholder="Enter pseudonyme" value={name} onChange={onNameInput} isInvalid={nameFeedback?.type == "invalid"}/>
            <Form.Control.Feedback type="invalid">
              {nameFeedback?.content}
            </Form.Control.Feedback>
          </Form.Group>

          <Form.Group className="mb-3" >
            <Form.Label>Password</Form.Label>
            <Form.Control type="password" placeholder="Password" value={password} onChange={onPasswordInput} isInvalid={passwordFeedback?.type == "invalid"}/>
            <Form.Control.Feedback type="invalid">
              {passwordFeedback?.content}
            </Form.Control.Feedback>
          </Form.Group>

          <Form.Group className="mb-3">
            <Form.Check type="checkbox" label="Stay signed-in" checked={staySignedIn} onChange={onStaySingedInput}/>
          </Form.Group>
          
          { 
            feedback === null ? null : (
              <Alert variant={feedback.alert}>
                {feedback?.content}
              </Alert>
            )
          }
          <Button variant="primary" type="submit">
            Submit
          </Button>
          <div className="mt-3">Already have an account?<Link className="ms-3" to="/login">Sign-In</Link></div>
        </Form>
      </div>
    </Container>
  );
}