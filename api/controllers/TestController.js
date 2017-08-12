/**
 * TestController
 *
 * @description :: Server-side logic for managing testes
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */

var bodyParser = require("body-parser");


module.exports = {

    //delete unavailable
    destroy: function (req, res) {
        return res.json(403, 'You don\'t have permission to DELETE');
    },

    //use TestService
    testCall: function (req, res) {

        var testMsg = TestServices.testFunction();

        res.send('Return: ' + testMsg);

    },
    execute: function (req, res) {

        var ret = ExecutionQueueServices.execute(res);

        return res.send(ret);
    },
    version: function(req, res){

         TestServices.version(req,res);

    }
};

