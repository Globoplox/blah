import {FormEvent, Dispatch} from "react";
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import Container from 'react-bootstrap/Container';
import Alert from 'react-bootstrap/Alert';
import { ErrorCode, Api, Error, ParameterError } from "../api";
import { ChangeEvent,useState } from 'react'
import { useNavigate } from "react-router";

export default function CreateProject({api}: {api: Api}) {
  const navigate = useNavigate();

  const [description, setDescription] = useState("");
  const [isPublic, setIsPublic] = useState(false);
  const [name, setName] = useState("");

  const [feedback, setFeedback] = useState(null);
  const [nameFeedback, setNameFeedback] = useState(null);
  const [descriptionFeedback, setDescriptionFeedback] = useState(null);

  const parameterFeedbacks : Record<string, Dispatch<{type: string, content: string, alert: string}>> = {
    "name": setNameFeedback,
    "description": setDescriptionFeedback,
  };

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    
    api.create_project(name, isPublic, description).then(project => {
      setFeedback({type: "valid", content: "Project successfully created", alert: "success"});
      setTimeout(() => { navigate(`/projects/${project.id}`) }, 1000)
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

  function onDescriptionInput(event: ChangeEvent<HTMLInputElement>) {
    setDescription(event.target.value);
  }

  function onNameInput(event: ChangeEvent<HTMLInputElement>) {
    setName(event.target.value);
  }

  function onIsPublicInput(event: ChangeEvent<HTMLInputElement>) {
    setIsPublic(event.target.checked);
  }

  return (
    <Container className="flex-flex">
      <div className="flex-flex center-center" >
        <Form onSubmit={onSubmit} style={{minWidth: "50%"}}>
          <h3 className="pb-3">Create a new project</h3>

          <Form.Group className="mb-3">
            <Form.Label>Name</Form.Label>
            <Form.Control type="text" placeholder="Enter project name" value={name} onChange={onNameInput} isInvalid={nameFeedback?.type == "invalid"}/>
            <Form.Control.Feedback type="invalid">
              {nameFeedback?.content}
            </Form.Control.Feedback>
          </Form.Group>

          <Form.Group className="mb-3" >
            <Form.Label>Description</Form.Label>
            <Form.Control as="textarea" rows={3} value={description} onChange={onDescriptionInput} isInvalid={descriptionFeedback?.type == "invalid"}/>
            <Form.Control.Feedback type="invalid">
              {descriptionFeedback?.content}
            </Form.Control.Feedback>
          </Form.Group>

          <Form.Group className="mb-3">
            <Form.Check type="checkbox" label="This is a public project" checked={isPublic} onChange={onIsPublicInput}/>
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
        </Form>
      </div>
    </Container>
  );
}