/**
 * MessageController
 *
 * @description :: Server-side logic for managing messages
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */
var bodyParser = require("body-parser");

module.exports = {
    //Disabling REST for this Controller
    // _config: {
    //     actions: false,
    //     shortcuts: false,
    //     rest: false
    // },

    //use TestService
    sendMessage: function (req, res) {

        var testMsg = MessageServices.sendMessage(req.body.to,
            req.body.subject,
            req.body.message,
            res);

        res.status(200).end("OK " + testMsg);

    },
    callMessages: function (req, res) {
        
        Message.query("SELECT ALL_MESSAGES_PRC()", function (err, results) {
            if (err)
                return res.serverError(err);
            return res.ok(results.rows);
        });
    }
};

