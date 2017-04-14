/**
 * `compileAssets`
 *
 * ---------------------------------------------------------------
 *
 * This Grunt tasklist is not designed to be used directly-- rather
 * it is a helper called by the `default`, `prod`, `build`, and
 * `buildProd` tasklists.
 *
 * For more information see:
 *   http://sailsjs.org/documentation/anatomy/my-app/tasks/register/compile-assets-js
 *
 * 
 * Alteração feita em relação a http://stackoverflow.com/questions/18139290/how-do-i-connect-bower-components-with-sails-js/22456574#22456574
 */
module.exports = function(grunt) {
  grunt.registerTask('compileAssets', [
    'clean:dev',
    'jst:dev',
    'less:dev',
    'copy:dev',
    'coffee:dev',
    'bower:dev'
  ]);
};
