import { BrowserRouter, Routes, Route } from "react-router";
import Api from "../api";
import Login from "./login";
import Register from "./register";
import Index from "./index";
import CreateProject from "./create_project";
import Project from "./project";
import { useNavigate } from "react-router";


/*
  TODO:
  - Running
  - TTY
  - File id in project routing ?
  - Filetree create file and directory buttons
  - Project page global toast
  - All auth related chore (reset, doube auth, email verification, oauth, device kick, ...)
  - Notifications for collaboration
  - Port sharing and scaling
*/

export default function App() {
  const api = new Api();

  return <BrowserRouter>
    <Routes>
      <Route index element={<Index api={api} />} />
      <Route path="login" element={<Login api={api}/>} />
      <Route path="register" element={<Register api={api}/>} />
      <Route path="project">
        <Route path="create" element={<CreateProject api={api} />} />
        <Route path=":projectId" element={<Project api={api} />} />
        <Route path=":projectId/file/:fileId" element={<Project api={api} />} />
      </Route>
    </Routes>
  </BrowserRouter>;

}