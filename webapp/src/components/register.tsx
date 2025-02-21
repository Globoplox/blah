import {FormEvent, Dispatch} from "react";
import Button from 'react-bootstrap/Button';
import Row from 'react-bootstrap/Row';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Image from 'react-bootstrap/Image';
import Container from 'react-bootstrap/Container';
import InputGroup from 'react-bootstrap/InputGroup';
import Alert from 'react-bootstrap/Alert';
import { ErrorCode, Api, Error, ParameterError } from "../api";
import { ChangeEvent, useState, useEffect, useRef } from 'react'
import { useNavigate, useSearchParams } from "react-router";
import { Link } from "react-router";
import "../pictures/default_avatar.jpg";

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

  const [avatar, setAvatar] = useState(null)
  const [preview, setPreview] = useState(null)

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
      if (avatar != null)
        api.set_avatar(avatar).catch(console.error);
      setFeedback({type: "valid", content: "Successfully signed-in", alert: "success"});
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


  const avatarInputRef = useRef(null);

  function onSetAvatar(e : ChangeEvent<HTMLInputElement>) {
    if (!e.target.files || e.target.files.length === 0) {
        setAvatar(null)
        return
    }

    setAvatar(e.target.files[0])
  }

  function onClearAvatar() {
    if (avatarInputRef.current)
      avatarInputRef.current.value = null;
    setAvatar(null);
  }

  useEffect(() => {
      if (!avatar) {
          setPreview(null);
          return
      }

      const objectUrl = URL.createObjectURL(avatar);
      setPreview(objectUrl);

      // free memory when ever this component is unmounted
      return () => URL.revokeObjectURL(objectUrl)
  }, [avatar])

  return (
    <Container className="flex-flex">
      <div className="flex-flex center-center">
        <Form onSubmit={onSubmit}>
          <h3 className="pb-3">Sign-up</h3>
          <Row>
            <Col>
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
            </Col>
            <Col>
              <Image className="d-block mx-auto mb-3" width="180" height="180" src={preview ? preview : "pictures/default_avatar.jpg"} roundedCircle />                

              <Form.Group className="mb-3">
                <InputGroup>
                  <Form.Control ref={avatarInputRef} type="file" onChange={onSetAvatar} placeholder="Pick an avatar"/>
                  <Button variant="outline-secondary" onClick={onClearAvatar} disabled={avatar == null}>
                    Clear
                  </Button>
                </InputGroup>
              </Form.Group>
            </Col>
          </Row>
    
          <Button variant="primary" type="submit">
            Submit
          </Button>
          <div className="mt-3">Already have an account?<Link className="ms-3" to="/login">Sign-In</Link></div>
        </Form>
      </div>
    </Container>
  );
}