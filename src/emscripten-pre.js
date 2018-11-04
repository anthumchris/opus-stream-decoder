Module['locateFile'] = function(filename) {
  // provide correct path when included from NodeJS package
  return ENVIRONMENT_IS_NODE ? __dirname+'/'+filename : filename;
}
