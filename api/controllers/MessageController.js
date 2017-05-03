/**
 * MessageController
 *
 * @description :: Server-side logic for managing messages
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */
var bodyParser = require("body-parser");

module.exports = {

    //use TestService
    sendMessage: function (req, res) {

        var testMsg = MessageServices.sendMessage(req.body.to,
                                                req.body.subject,
                                                req.body.message,
                                                res);

        res.status(200).end("OK " + testMsg);

    }
};

