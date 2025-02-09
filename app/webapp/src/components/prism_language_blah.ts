import {languages} from "prism-react-editor/prism";

languages.blah = {
  'comment': {
      pattern: /#.*|^=begin\s[\s\S]*?^=end/m,
      greedy: true
		},

	'string': {
		pattern: /(["'])(?:\\(?:\r\n|[\s\S])|(?!\1)[^\\\r\n])*\1/,
		greedy: true
	},

	'class-name': {
		pattern: /(\b(?:class|extends|implements|instanceof|interface|new|trait)\s+|\bcatch\s+\()[\w.\\]+/i,
		lookbehind: true,
		inside: {
			'punctuation': /[.\\]/
		}
	},
	
  'keyword': /\b(?:addi|add|nand|sw|lw|beq|jalr|lui|lli|movi|nop|halt|.ascii|section|weak|export)\b/,
	
  'function': [
    /\b\w+(?=:)/,
    /[:][a-zA-Z0-9_-]*/,
  ],
	
  'number': /\b0x[\da-f]+\b|(?:\b\d+(?:\.\d*)?|\B\.\d+)(?:e[+-]?\d+)?/i,


  register: {
    pattern: /\br[0-7]/,
    alias: 'number'
  },

	'operator': /[<>]=?|[!=]=?=?|--?|\+\+?|&&?|\|\|?|[?*/~^%]/,
	
  'punctuation': /[{}[\];(),.:]/

  /*
  comment: {
    pattern: /#.*|^=begin\s[\s\S]*?^=end/m,
    greedy: true
  },

  keyword: {
    pattern: /\b(section|weak|export)\b/,
    alias: 'keyword'
  },

  memo: {
    pattern: /addi|add|nand|sw|lw|beq|jalr|lui|lli|movi|nop|halt|.ascii/,
    alias: 'builtin'
  },

  string: {
		pattern: /(["'])(?:\\(?:\r\n|[\s\S])|(?!\1)[^\\\r\n])*\1/,
		greedy: true
	},

  reference: {
    pattern: /\b:[a-zA-Z_][a-zA-Z0-9-_]*\b/,
    alias: 'function'
  },

  definition: {
    pattern: /\b[a-zA-Z_][a-zA-Z0-9-_]*:\b/,
    alias: 'function'
  },


  sectionName: {
    //pattern: /\b[a-zA-Z_][a-zA-Z0-9-_]\b/,
    pattern: /\b\w+(?=\()/,
    alias: 'function'
  },

  register: {
    pattern: /r[0-7]/,
    alias: 'number'
  },



	number: /\b0x[\da-f]+\b|(?:\b\d+(?:\.\d*)?|\B\.\d+)(?:e[+-]?\d+)?/i,

  operator: /[+-]/,*/
};
