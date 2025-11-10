#!/bin/bash
npm i codemirror @codemirror/lang-python
npm i rollup @rollup/plugin-node-resolve
node_modules/.bin/rollup ./src/main/resources/static/js/testPage.mjs \
-f iife \
-o ./src/main/resources/static/js/testPage.js \
-p @rollup/plugin-node-resolve

mvn -Dmaven.test.skip=true package
