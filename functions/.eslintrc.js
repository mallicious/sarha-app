module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2018,
  },
  extends: [
    "eslint:recommended",
  ],
  rules: {
    "indent": "off",
    "max-len": "off",
    "no-trailing-spaces": "off",
    "comma-dangle": "off",
    "eol-last": "off",
  },
};