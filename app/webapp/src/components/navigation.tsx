import Container from 'react-bootstrap/Container';
import Navbar from 'react-bootstrap/Navbar';
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
import { FaUnlock } from "react-icons/fa";
import { FaLock } from "react-icons/fa";
import { FaPen } from "react-icons/fa";
import { FaHome } from "react-icons/fa";

export default function Navigation({api}: {api: Api}) {

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
      <Image className="ms-3" width="32" height="32" src={user.avatar_uri ? user.avatar_uri : "/pictures/default_avatar.jpg"} roundedCircle />
    </span>;
  }

  return (
    <Navbar style={{height: "0.5in"}} className="bg-body-tertiary">
      <Container fluid>
        <Navbar.Brand href="#">Blah</Navbar.Brand>
        <Navbar.Collapse id="navbarScroll">
          <Nav
            className="me-auto my-2 my-lg-0"
            style={{ maxHeight: '100px' }}
            navbarScroll
          />
          <div className="d-flex">{user ? <Self/> : <Anonymous/>}</div>
        </Navbar.Collapse>
      </Container>
    </Navbar>
  );
}