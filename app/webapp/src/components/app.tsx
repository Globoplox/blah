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
  - ACL
  - Markdown
  - Debugger might actually works as is with xtermjs
  - Might need a bigger tty for this
  - Filetree create file and directory buttons and maybe RUN on recipe files ?
  - Api job auto cleaning
  - Project page global toast
  - All auth related chore (reset, doube auth, email verification, oauth, device kick, ...)
  - Notifications for collaboration and diff ?
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
        <Route path=":projectId/file?/*" element={<Project api={api} />} />
      </Route>
    </Routes>
  </BrowserRouter>;

}