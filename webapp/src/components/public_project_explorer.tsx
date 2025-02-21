import Container from 'react-bootstrap/Container';
import Navbar from 'react-bootstrap/Navbar';
import Stack from 'react-bootstrap/Stack';
import { ChangeEvent, useState, KeyboardEvent, useEffect } from 'react';
import Form from 'react-bootstrap/Form';
import Accordion from 'react-bootstrap/Accordion';
import { ErrorCode, Api, Project, ProjectListEntry } from "../api";
import Button from 'react-bootstrap/Button';
import InputGroup from 'react-bootstrap/InputGroup';
import { Link } from "react-router";
import Spinner from 'react-bootstrap/Spinner';
import { FaSearch } from "react-icons/fa";
import { useNavigate, useSearchParams, useLocation } from "react-router";
import "../pictures/default_project_avatar.jpg";
import "./public_project_explorer.scss";

import Image from 'react-bootstrap/Image';

export default function PublicExplorer({api, style} : {api: Api, style: React.CSSProperties}) {

  function ProjectExplorerEntry({project} : {project: ProjectListEntry}) {
    return <Accordion.Item eventKey={project.id}>
        <Accordion.Header>
          <Link className="soft-link" to={`/project/${project.id}`}>
          <Image className="border" width="32" height="32" src={project.avatar_uri ? project.avatar_uri : "/pictures/default_project_avatar.jpg"} roundedCircle />
          <span className="ms-3">{project.owner_name} / {project.name}</span>
          </Link>
        </Accordion.Header>
        <Accordion.Body>
          {project.description}
        </Accordion.Body>
      </Accordion.Item>;
  }

  function ProjectList({projects}: {projects: ProjectListEntry[]}) {
    return <Accordion className="no-select-color">
      {projects.map(_ => 
        <ProjectExplorerEntry key={_.id} project={_}/>
      )}
    </Accordion>;
  }

  const [query, setQuery] = useState("");
  const [entries, setEntries] = useState([] as ProjectListEntry[]);
  const [isLoaded, setIsLoaded] = useState(false);
  const loadProjects = useEffect(() => search(""), []);
  const navigate = useNavigate();
  const location = useLocation();

  function search(query: string) {
    api.public_projects(query).then(projects => {
      setIsLoaded(true);
      setEntries(projects);
    }).catch(error => {
      if (error.code === ErrorCode.Unauthorized)
        navigate(`/login?redirectTo=${location.pathname}`);
    });
  }

  function onChange(e: ChangeEvent<HTMLInputElement>) {
      setQuery(e.target.value);
      search(e.target.value);
  };

  function onKeydown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.code === 'Enter' && e.currentTarget.value === '')
        search('');
  }

  return (
    <Stack gap={3} style={style} className="p-3">
      <h4>Public projects</h4>

      <InputGroup className="mb-3">
        <Form.Control
          type="text" 
          value={query}
          placeholder="Search"
          onChange={onChange}
          onKeyDown={onKeydown}
        />
        <InputGroup.Text><FaSearch /></InputGroup.Text>
      </InputGroup>

      {
        isLoaded
        ? <ProjectList projects={entries} /> 
        : <div className="d-flex align-items-center">
            <Spinner size="sm"/>
            <strong className="ms-2">Loading...</strong>
          </div>
      }
      
    </Stack>
  );
}