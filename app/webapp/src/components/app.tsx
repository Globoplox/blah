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
  - Retry debugger hosted in the same process
  - If it does works, implement an easy in house FS for temporary files in jobs
  - Seed some public projects in migrations
  - Avatar, acl UI, public project explorer

  - Test ACL

  - Temporary directory specifier that create a job local space for files that are not persisted
  - Markdown
  - Filetree create file and directory buttons and maybe RUN on recipe files ?
  - Project page global toast
  - All auth related chore (reset, doube auth, email verification, oauth, device kick, ...)
  - Notifications for collaboration and diff ?
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