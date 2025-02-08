const API_SERVER_URI = process.env.API_SERVER_URI;

// Api error codes
export enum ErrorCode {
  Unauthorized = "unauthorized",
  InvalidCrdentials = "invalid_credentials",
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
  id: string,
  path: string,
  content_uri: string,
  created_at: string,
  file_edited_at: string,
  author_name: string,
  editor_name: string,
  is_directory: boolean
}

export type Project = {
  id: string,
  name: string,
  public: boolean,
  description: string | null,
  created_at: string,
  owner_name: string,
  files?: File[]
}
export type IDResponse = {id: string}

export class Api {

  #headers = new Headers({'content-type': 'application/json'})

  mapNetworkError(error: unknown): Promise<Error> {
      return Promise.reject({code: ErrorCode.NetworkError, error: "Network error", message: JSON.stringify(error)})
  }

  login(email: string, password: string, staySignedIn : boolean) : Promise<null | Error> {
    const body = {email, password, stay_signed: staySignedIn};

    return fetch(
      `${API_SERVER_URI}/login`, {method: "PUT", headers: this.#headers, body: JSON.stringify(body), credentials: 'include'}
    ).then(response => {
        if (response.ok)
          return null
        else 
          return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError)
  }

  register(email: string, name: string, password: string, staySignedIn : boolean) : Promise<null> {
    const body = {email, name, password, stay_signed: staySignedIn};

    return fetch(
      `${API_SERVER_URI}/register`, {method: "POST", headers: this.#headers, body: JSON.stringify(body), credentials: 'include'}
    ).then(response => {
        if (response.ok)
          return null
        else 
          return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError) as unknown as Promise<null>
  }

  create_project(name: string, isPublic: boolean, description: string) : Promise<IDResponse> {
    const body = {name, description, public: isPublic};

    return fetch(
      `${API_SERVER_URI}/projects/create`, {method: "POST", headers: this.#headers, body: JSON.stringify(body), credentials: 'include'}
    ).then(response => {
        if (response.ok)
          return response.json()
        else 
          return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError)
  }

  public_projects(query : string) : Promise<Project[]> {
    return fetch(
      `${API_SERVER_URI}/projects/public?query=${query}`, {method: "GET", headers: this.#headers, credentials: 'include'}
    ).then(response => {
        if (response.ok)
          return response.json()
        else 
          return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError)
  }

  owned_projects(query : string) : Promise<Project[]> {
    return fetch(
      `${API_SERVER_URI}/projects/owned?query=${query}`, {method: "GET", headers: this.#headers, credentials: 'include'}
    ).then(response => {
        if (response.ok)
          return response.json()
        else 
          return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError)
  }

  read_project(project_id: string) : Promise<Project> {
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}`, {method: "GET", headers: this.#headers, credentials: 'include'}
    ).then(response => {
        if (response.ok)
          return response.json()
        else 
          return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError)
  }

  create_file(project_id: string, path: string) : Promise<IDResponse> {
    const body = {path};
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}/file`, {method: "POST", headers: this.#headers, credentials: 'include', body: JSON.stringify(body)}
    ).then(response => {
        if (response.ok)
          return response.json()
        else 
          return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError)
  }

  create_directory(project_id: string, path: string) : Promise<IDResponse> {
    const body = {path};
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}/directory`, {method: "POST", headers: this.#headers, credentials: 'include', body: JSON.stringify(body)}
    ).then(response => {
        if (response.ok)
          return response.json()
        else 
          return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError)
  }

  move_file(project_id: string, file_id: string, path: string) : Promise<null> {
    const body = {new_path: path};
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}/files/${file_id}/move`, {method: "PUT", headers: this.#headers, credentials: 'include', body: JSON.stringify(body)}
    ).then(response => {
        if (response.ok)
          return null
        else 
          return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError) as unknown as Promise<null>
  }

  delete_file(project_id: string, file_id: string) : Promise<null> {
    return fetch(
      `${API_SERVER_URI}/projects/${project_id}/files/${file_id}`, {method: "DELETE", headers: this.#headers, credentials: 'include'}
    ).then(response => {
        if (response.ok)
          return null
        else 
          return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError) as unknown as Promise<null>
  }
}

export default Api;