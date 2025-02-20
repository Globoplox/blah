import {FormEvent} from "react";
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import Container from 'react-bootstrap/Container';
import Alert from 'react-bootstrap/Alert';
import { ErrorCode, Api, Error, ParameterError, Project, ACLEntry } from "../api";
import { ChangeEvent, useState, useEffect } from 'react'
import { useNavigate, useSearchParams } from "react-router";
import { Link } from "react-router";
import { FaUnlock } from "react-icons/fa";
import { FaLock } from "react-icons/fa";
import { FaPen } from "react-icons/fa";
import { FaHome } from "react-icons/fa";
import Badge from 'react-bootstrap/Badge';
import Stack from 'react-bootstrap/Stack';
import NavDropdown from 'react-bootstrap/NavDropdown';
import Modal from 'react-bootstrap/Modal';
import Image from 'react-bootstrap/Image';
import "../pictures/default_avatar.jpg";
import InputGroup from 'react-bootstrap/InputGroup';
import Row from 'react-bootstrap/Row';
import Col from 'react-bootstrap/Col';
import ListGroup from 'react-bootstrap/ListGroup';
import CloseButton from 'react-bootstrap/CloseButton';

export default function ACLControl({api, project}: {api: Api, project: Project}) {
  const [query, setQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);

  useEffect(() => {
    api.read_project_acl(project.id, query).then(setSearchResults);
  }, [query]);

  const tags = [];

  if (project.public)
    tags.push("public");
  else
    tags.push("private");

  if (project.owned)
    tags.push("owned");
  else {
    if (project.can_write)
      tags.push("write access")
    else
      tags.push("read only")
  }

  function AclListEntry({acl}: {acl: ACLEntry}) {
    const isYou = acl.user_id == api.user?.id;

    const [mode, setMode] = useState(isYou ? 3 : getMode(acl));

    function getMode(acl: ACLEntry) : string {
      if (acl.can_read && acl.can_write)
        return "3";
      else if (acl.can_read)
        return "2";
      return "1";
    }

    function onChange(e: ChangeEvent<HTMLSelectElement>) {
      let can_read = false;
      let can_write = false;

      if (e.target.value == "2") {
        can_read = true;
      }

      if (e.target.value == "3") {
        can_read = true;
        can_write = true;
      }

      setMode(e.target.value)

      api.set_project_acl(project.id, acl.user_id, can_read, can_write).then(_ => {
      });
    }


    return <Row className="mt-2 d-flex">
     <Col xs="5">
        <Form.Select disabled={isYou} className="ms-2" size="sm" value={mode} onChange={onChange}>
          <option value="1">No Access</option>
          <option value="2">Read only</option>
          <option value="3">Read & Write</option>
        </Form.Select>
      </Col>
      <Col xs="7">
        <Image width="32" height="32" src={acl.avatar_uri ? acl.avatar_uri : "/pictures/default_avatar.jpg"} roundedCircle />
        <u className="ms-3 my-auto">{acl.name}</u>
        {isYou ? <span className="ms-1">(you)</span> : <></>}
      </Col>
    </Row>;
  }

  const tagsElement = <Stack direction="horizontal" gap={2}>
    {tags.map(tag => <Badge key={tag} bg="secondary">{tag}</Badge>)}
  </Stack>;

  if (project.owned == false)
    return <span>{`${project.owner_name} / ${project.name}`}{tagsElement}</span>;

  return <>
    <NavDropdown className="ms-auto" title={`${project.owner_name} / ${project.name}`} id="basic-nav-dropdown">
      <Container style={{width: "400px"}} className="justify-content-around">

        <Form.Control type="text" placeholder="Search user by name" value={query} onChange={e => setQuery(e.target.value)}/>

        <NavDropdown.Divider />

          {searchResults.length != 0 ? 
            <>
            {searchResults.map((acl: ACLEntry) => <AclListEntry key={acl.user_id} acl={acl}/>)}
          </>: <span className="text-secondary mx-auto">No contributor added</span>
          }
      </Container>
    </NavDropdown>{tagsElement}
  </>;
}