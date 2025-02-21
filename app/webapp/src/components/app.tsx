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
  - Markdown
  - Doc
  - File organization
  - Fixing project.tsx
  - Re-open notifications sockets if closed when back to page ?



  - Self Profile page
  - Disconnect button in uri

  - Can access projects without user if project is public

    Public (Owned) / Public / Private (owned) / Private (can read) / Private (can write)
    If private owned, is a dropdown
      With avatar and name of users and a checkbox of right

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