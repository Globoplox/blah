import {languages} from "prism-react-editor/prism";

languages.stacklang = {
  ...languages.clike,
	
  keyword: /\b(?:var|require|if|while|fun|return)\b/,
};
