import Container from 'react-bootstrap/Container';
import Navbar from 'react-bootstrap/Navbar';
import Stack from 'react-bootstrap/Stack';
import { ChangeEvent, useState, KeyboardEvent, useEffect } from 'react';
import Form from 'react-bootstrap/Form';
import Accordion from 'react-bootstrap/Accordion';
import { ErrorCode, Api, Project } from "../api";
import Button from 'react-bootstrap/Button';
import InputGroup from 'react-bootstrap/InputGroup';
import { Link } from "react-router";
import Spinner from 'react-bootstrap/Spinner';
import { FaSearch } from "react-icons/fa";

export default function ProjectExplorer({api, style} : {api: Api, style: React.CSSProperties}) {

  function ProjectExplorerEntry({project} : {project: Project}) {
    return <div><Link className="soft-link" to={`/project/${project.id}`}>{project.owner_name}/{project.name}</Link></div>;
  }

  function ProjectList({projects}: {projects: Project[]}) {
    if (projects.length == 0) {
      return <p className="text-center">
        You dont have created any project yet.
      </p>;
    } else {
      return projects.map(_ => 
          <ProjectExplorerEntry key={_.id} project={_}/>
      );
    }
  }

  const [query, setQuery] = useState("");
  const [entries, setEntries] = useState([] as Project[]);
  const [isLoaded, setIsLoaded] = useState(false);
  const loadProjects = useEffect(() => search(""), []);

  function search(query: string) {
    api.owned_projects(query).then(projects => {
      setIsLoaded(true);
      setEntries(projects);
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
      <Stack direction="horizontal" gap={3}>
        <h4>Your projects</h4>
       
          <Link className="ms-auto" to="/project/create">
            <Button  variant="success">
              Create
            </Button>
          </Link>
 
      </Stack>

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