/**
 * MessageController
 *
 * @description :: Server-side logic for managing messages
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */
var bodyParser = require("body-parser");
module.exports = {

    //utiliza o TesteService criado
    sendMessage: function (req, res) {

        // console.log(">> " + req.body.to);
        // console.log(">> " + req.body.subject);
        // console.log(">> " + req.body.message);
        
        var testeMsg = MessageServices.sendMessage(req.body.to,
                                                    req.body.subject,
                                                    req.body.message,
                                                     res);

           res.status(200).end("OK " + testeMsg );

    }

};

