import Container from 'react-bootstrap/Container';
import Navbar from 'react-bootstrap/Navbar';
import ACLControl from "./acl_control"
import { ErrorCode, Api, Error, ParameterError, Project } from "../api";
import Row from 'react-bootstrap/Row';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Image from 'react-bootstrap/Image';
import "../pictures/default_avatar.jpg";
import Button from 'react-bootstrap/Button';
import Nav from 'react-bootstrap/Nav';
import NavDropdown from 'react-bootstrap/NavDropdown';
import { ChangeEvent, useState, KeyboardEvent, useEffect, useRef } from 'react';


export default function Navigation({api, project}: {api: Api, project?: Project}) {

  const [user, setUser] = useState(api.user);

  function onUserChange(event: any) {
    setUser(event.data);
  }

  useEffect(() => {
    api.emitter.addEventListener('user-change', onUserChange);
    return () => {
      api.emitter.removeEventListener('user-change', onUserChange);
    };
  });

  function ProjectInfo({project}: {project: Project}) {
    /*
      api call to check if: public, owned, can write, acls
    */
  }

  function Anonymous() {
    return <>Guest</>;
  }

  function Self() {
    return <span>
      <u className="my-auto">{user.name}</u>
      <Image className="border ms-3" width="32" height="32" src={user.avatar_uri ? user.avatar_uri : "/pictures/default_avatar.jpg"} roundedCircle />
    </span>;
  }

  return (
    <Navbar style={{height: "0.5in"}} className="bg-body-tertiary">
      <Container fluid className="justify-content-between">
        <Navbar.Brand href="/">Blah</Navbar.Brand>
        <Nav>
          {project ? <ACLControl api={api} project={project}/> : <></>}
        </Nav>
        <div>{user ? <Self/> : <Anonymous/>}</div>
      </Container>
    </Navbar>
  );
}