import Stack from 'react-bootstrap/Stack';
import Navigation from "./navigation";
import ProjectExplorer from "./project_explorer";
import PublicExplorer from "./public_project_explorer";
import Container from 'react-bootstrap/Container';
import { ErrorCode, Api, Error, ParameterError } from "../api";

export default function Index({api} : {api: Api}) {

  return (
    <Stack style={{width: "100%"}}>
      <Navigation api={api}></Navigation>
      <hr style={{margin: 0}}/>
      <Stack direction="horizontal" style={{height: "100%", width: "100%"}}>
        <ProjectExplorer style={{maxWidth: "17.5%", height: "100%"}} api={api} />
        <div className="vr" />
        <Stack gap={3}>
          <PublicExplorer style={{width: "55%", height: "100%", marginLeft: "auto", marginRight: "auto"}} api={api}/>
        </Stack>
      </Stack>
    </Stack>
  );
}