const API_SERVER_URI = process.env.API_SERVER_URI;

// Api error codes
export enum ErrorCode {
  Unauthorized = "unauthorized",
  InvalidCredentials = "invalid_credentials",
  BadParameter = "bad_parameter",
  BadRequest = "bad_request",
  ServerError = "server_error",
  // This one is used to produce mock api error incase of network error on client side 
  NetworkError = "network",
}

type BaseError = {code: ErrorCode, error: string, message: string | null}

export type ParameterError = {code: ErrorCode.BadParameter, error: string, message: string | null, parameters : {name: string, issue: string}[]}
export type Error = ParameterError | BaseError

export type File = {
  project_id: string,
  path: string,
  content_uri: string,
  created_at: string,
  file_edited_at: string,
  author_name: string,
  editor_name: string,
  is_directory: boolean
}

export type ProjectNotification = 
  {event: 'created', file: File} | 
  {event: 'moved', old_path: string, file: File} | 
  {event: 'deleted', path: string}


export type ProjectListEntry = {
  id: string,
  name: string,
  public: boolean,
  description: string | null,
  created_at: string,
  owner_name: string
}

export type Project = {
  id: string,
  name: string,
  public: boolean,
  description: string | null,
  created_at: string,
  owner_name: string,
  files: File[],
  owned: boolean,
  can_write: boolean,
  acl: ACLEntry[]
}

export type Job = {
  id: string,
  success: boolean,
  completed: boolean,
  started: boolean
}

export type User = {
  name: string,
  avatar_uri: string,
  id: string
}

export type IDResponse = {id: string}

export type ACLEntry = {
  user_id: string,
  name: string,
  avatar_uri: string,
  can_write: boolean,
  can_read: boolean,
}

export class Api {

  #headers = new Headers({'content-type': 'application/json'})
  user : User = null
  emitter = new EventTarget();

  constructor() {
    this.self().catch(error => {
      if (error.code != ErrorCode.Unauthorized)
        return error;
    });
  }

  handleError(error: Error) {
    return Promise.reject(error)
  }

  mapNetworkError(error: unknown): Promise<Error> {
      return Promise.reject({code: ErrorCode.NetworkError, error: "Network error", message: JSON.stringify(error)})
  }

  login(email: string, password: string, staySignedIn : boolean) : Promise<User> {
    const body = {email, password, stay_signed: staySignedIn};
    return fetch(
      `${API_SERVER_URI}/login`, {method: "PUT", headers: this.#headers, body: JSON.stringify(body), credentials: 'include'}
    ).then(response => {
      if (response.ok)
        return response.json().then((user: User) => {
          this.user = user;
          const event = new Event('user-change');
          (event as any).data = user;
          this.emitter.dispatchEvent(event);
          return user
        });
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError) as unknown as Promise<User>
  }

  self() : Promise<User> {
    return fetch(
      `${API_SERVER_URI}/self`, {method: "GET", headers: this.#headers, credentials: 'include'}
    ).then(response => {
      if (response.ok)
        return response.json().then((user: User) => {
          this.user = user;
          const event = new Event('user-change');
          (event as any).data = user;
          this.emitter.dispatchEvent(event);
          return user
        });
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError) as unknown as Promise<User>
  }

  register(email: string, name: string, password: string, staySignedIn : boolean) : Promise<User> {
    const body = {email, name, password, stay_signed: staySignedIn};

    return fetch(
      `${API_SERVER_URI}/register`, {method: "POST", headers: this.#headers, body: JSON.stringify(body), credentials: 'include'}
    ).then(response => {
      if (response.ok) 
        return response.json().then((user: User) => {
          this.user = user;
          const event = new Event('user-change');
          (event as any).data = user;
          this.emitter.dispatchEvent(event);
          return user
        });
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError) as unknown as Promise<User>
  }

  create_project(name: string, isPublic: boolean, description: string) : Promise<IDResponse> {
    const body = {name, description, public: isPublic};

    return fetch(
      `${API_SERVER_URI}/projects/create`, {method: "POST", headers: this.#headers, body: JSON.stringify(body), credentials: 'include'}
    ).then(response => {
      if (response.ok)
        return response.json()
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError)
  }

  public_projects(query : string) : Promise<ProjectListEntry[]> {
    return fetch(
      `${API_SERVER_URI}/projects/public?query=${query}`, {method: "GET", headers: this.#headers, credentials: 'include'}
    ).then(response => {
      if (response.ok)
        return response.json()
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError)
  }

  owned_projects(query : string) : Promise<ProjectListEntry[]> {
    return fetch(
      `${API_SERVER_URI}/projects/owned?query=${query}`, {method: "GET", headers: this.#headers, credentials: 'include'}
    ).then(response => {
      if (response.ok)
        return response.json()
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError)
  }

  read_project(project_id: string) : Promise<Project> {
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}`, {method: "GET", headers: this.#headers, credentials: 'include'}
    ).then(response => {
      if (response.ok)
        return response.json()
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError)
  }

  read_project_acl(project_id: string, query?: string) : Promise<ACLEntry[]> {
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}/acl?query=${query}`, {method: "GET", headers: this.#headers, credentials: 'include'}
    ).then(response => {
      if (response.ok)
        return response.json()
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError)
  }

  set_project_acl(project_id: string, user_id: string, can_read: boolean, can_write: boolean) : Promise<null> {
    const body = {
      user_id, can_read, can_write
    };

    return fetch(
      `${API_SERVER_URI}/projects/${project_id}/acl`, {method: "PUT", headers: this.#headers, credentials: 'include', body: JSON.stringify(body)}
    ).then(response => {
      if (response.ok)
        return null
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError) as unknown as Promise<null>
  }

  create_file(project_id: string, path: string) : Promise<File> {
    const body = {path};
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}/file`, {method: "POST", headers: this.#headers, credentials: 'include', body: JSON.stringify(body)}
    ).then(response => {
      if (response.ok)
        return response.json()
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError)
  }

  create_directory(project_id: string, path: string) : Promise<File> {
    const body = {path};
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}/directory`, {method: "POST", headers: this.#headers, credentials: 'include', body: JSON.stringify(body)}
    ).then(response => {
      if (response.ok)
        return response.json()
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError)
  }

  move_file(project_id: string, old_path: string, new_path: string) : Promise<null> {
    const body = {old_path, new_path};
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}/files/move`, {method: "PUT", headers: this.#headers, credentials: 'include', body: JSON.stringify(body)}
    ).then(response => {
      if (response.ok)
        return null
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError) as unknown as Promise<null>
  }

  delete_file(project_id: string, path: string) : Promise<null> {
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}/files${path}`, {method: "DELETE", headers: this.#headers, credentials: 'include'}
    ).then(response => {
      if (response.ok)
        return null
      else 
      return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError) as unknown as Promise<null>
  }

  update_file(project_id: string, path: string, content: string) : Promise<File> {
    const body = {content};
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}/files${path}`, {method: "PUT", headers: this.#headers, credentials: 'include', body: JSON.stringify(body)}
    ).then(response => {
      if (response.ok)
        return response.json()
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError) as unknown as Promise<null>
  }

  register_notification(project_id: string, handler: (socket: WebSocket) => void) : void {
    const socket = new WebSocket(`${API_SERVER_URI}/projects/${project_id}/notifications`);
    socket.addEventListener("open", _ => {
      handler(socket);
    });
  }

  run_file(project_id: string, path: string) : WebSocket {
    return new WebSocket(`${API_SERVER_URI}/project/${project_id}/job/recipe${path}`);
  }

  set_avatar(avatar : any) : Promise<null> {
    return fetch(
      `${API_SERVER_URI}/users/self/avatar`, {method: "POST", headers: {...this.#headers, "Content-Type": avatar.type}, credentials: 'include', body: avatar}
    ).then(response => {
      if (response.ok)
        return null
      else 
        return response.json().then(this.handleError.bind(this))
    }, this.mapNetworkError) as unknown as Promise<null>
  }
}

export default Api;