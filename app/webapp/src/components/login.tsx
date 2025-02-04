import {FormEvent} from "react";
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import Container from 'react-bootstrap/Container';
import Alert from 'react-bootstrap/Alert';
import { ErrorCode, Api, Error, ParameterError } from "../api";
import { ChangeEvent, useState } from 'react'
import { useNavigate } from "react-router";
import { Link } from "react-router";

export default function Login({api, redirectTo}: {api: Api, redirectTo: string | null}) {
  const navigate = useNavigate();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [staySignedIn, setStaySignedIn] = useState(false);
  const [feedback, setFeedback] = useState(null);

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    api.login(email, password, staySignedIn).then(_ => {
      setFeedback({type: "valid", content: "Successfully logged in", alert: "success"});
      setTimeout(() => { navigate(redirectTo || "/") }, 1000)
    }).catch(error => {
      if (error.code === ErrorCode.InvalidCrdentials)
        setFeedback({type: "invalid", content: error.message || error.error, alert: "warning"});
      else
        setFeedback({type: "invalid", content: error.message || error.error, alert: "danger"});
    })
    return false;
  }

  function onEmailInput(event: ChangeEvent<HTMLInputElement>) {
    setEmail(event.target.value);
  }

  function onPasswordInput(event: ChangeEvent<HTMLInputElement>) {
    setPassword(event.target.value);
  }

  function onStaySingedInput(event: ChangeEvent<HTMLInputElement>) {
    setStaySignedIn(event.target.checked);
  }

  return (
    <Container className="flex-flex">
      <div className="flex-flex center-center" >
        <Form onSubmit={onSubmit}>
          <h3 className="pb-3">Sign-in</h3>

          <Form.Group className="mb-3" controlId="formBasicEmail">
            <Form.Label>Email address</Form.Label>
            {/* Not using type="email" because something then fuck up the form by adding random validation popup */}
            <Form.Control type="text" placeholder="Enter email" value={email} onChange={onEmailInput} isInvalid={feedback?.type == "invalid"}/>
          </Form.Group>

          <Form.Group className="mb-3" controlId="formBasicPassword">
            <Form.Label>Password</Form.Label>
            <Form.Control type="password" placeholder="Password" value={password} onChange={onPasswordInput} isInvalid={feedback?.type == "invalid"}/>
          </Form.Group>

          <Form.Group className="mb-3" controlId="formBasicCheckbox">
            <Form.Check type="checkbox" label="Stay signed-in" checked={staySignedIn} onChange={onStaySingedInput}/>
          </Form.Group>
          
          { 
            feedback === null ? null : (
              <Alert variant={feedback.alert}>
                {feedback.content}
              </Alert>
            )
          }
          <Button variant="primary" type="submit">
            Submit
          </Button>
          <div className="mt-3">Don't have an account?<Link className="ms-3" to="/register">Sign-Up</Link></div>
        </Form>
      </div>
    </Container>
  );
}