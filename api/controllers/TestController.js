/**
 * TestController
 *
 * @description :: Server-side logic for managing testes
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */



module.exports = {

    //delete unavailable
    destroy: function (req, res) {
        return res.json(403, 'You don\'t have permission to DELETE');
    },

    //use TestService
    testCall: function (req, res) {

        var testeMsg = TestService.testFunction();

        res.send('Return: ' + testMsg);

    }
};

