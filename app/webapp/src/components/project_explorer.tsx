import Container from 'react-bootstrap/Container';
import Navbar from 'react-bootstrap/Navbar';
import Stack from 'react-bootstrap/Stack';
import { ChangeEvent, useState, KeyboardEvent } from 'react';
import Form from 'react-bootstrap/Form';
import Accordion from 'react-bootstrap/Accordion';
import { ErrorCode, Api, Error, ParameterError } from "../api";
import Button from 'react-bootstrap/Button';
import InputGroup from 'react-bootstrap/InputGroup';
import { Link } from "react-router";

function ProjectExplorerEntry() {
  return <div></div>;
}

export default function ProjectExplorer({api, style} : {api: Api, style: React.CSSProperties}) {

  const [query, setQuery] = useState("");
  const [entries, setEntries] = useState([]);

  function search(query: string) {
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
          size='lg'
          type="text" 
          value={query}
          placeholder="Search"
          onChange={onChange}
          onKeyDown={onKeydown}
        />
        <InputGroup.Text><i className="bi bi-search"></i></InputGroup.Text>
      </InputGroup>

      <Accordion flush>
        {entries.map(_ => 
            <ProjectExplorerEntry/>
        )}
        </Accordion>
    </Stack>
  );
}