/*
* 
* Alteração feita para http://stackoverflow.com/questions/18139290/how-do-i-connect-bower-components-with-sails-js/22456574#22456574
*
*/
module.exports = function(grunt) {
  grunt.config.set('bower', {
    dev: {
        dest: '.tmp/public',
        js_dest: '.tmp/public/js',
        css_dest: '.tmp/public/styles'
    }
  });

  grunt.loadNpmTasks('grunt-bower');

};