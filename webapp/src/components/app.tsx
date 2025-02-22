import { BrowserRouter, Routes, Route } from "react-router";
import Api from "../api";
import Login from "./login";
import Register from "./register";
import Index from "./index";
import CreateProject from "./create_project";
import Project from "./project";

/*
  TODO:

  - Api integration/regression tests testing
  - Recipe call from receipe (with parameters)
  - Fixing project.tsx
  - Re-open notifications sockets if closed when back to page ?
  - Self Profile page
  - Disconnect button in uri
  - Can access projects without user if project is public
  - All auth related chore (reset, doube auth, email verification, oauth, device kick, ...)
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