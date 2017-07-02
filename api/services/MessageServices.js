var send = require('gmail-send')({
    user: 'gerpro.noreply@gmail.com', //message sender account
    pass: 'Gerpro123'                 // password
    // html:    '<b>html text text</b>' //HTML body, if necessary
});

var bodyParser = require("body-parser");

//########################################
//#########     MAILGUN    ###############
//########################################

var api_key = 'key-8b0b023f19ab06f278dc2db893097b96';
var domain = 'sandbox144485e953204a3aae1777988fc008be.mailgun.org';
var mailgun = require('mailgun-js')({ apiKey: api_key, domain: domain });

var _from = 'GERPRO no-reply <mailgun@sandbox144485e953204a3aae1777988fc008be.mailgun.org>';
//########################################
//########################################
//########################################


var MessageServices = {

    sendMailGun: function mailGunMessageService(_to, _subject, _message, res) {

        if (!_to || !_subject || !_message) {

            sails.log.error("Invalid Message: " +
                " To: " + _to +
                " Subject: " + _subject +
                " Message: " + _message);
            return false;
        }


        var data = {
            from: _from,
            to: _to,
            subject: '[GERPRO] ' + _subject,
            text: _message
        };

        mailgun.messages().send(data, function (error, body) {

            sails.log(">>> SENDING... >>>");
            sails.log(body);

            if (!error) {

                var m = {
                    to: _to,
                    subject: _subject,
                    message: "ID: " + body.id + "\nMailgun Status: " + body.message + "\nMessage: " + _message
                };

                sails.log("*********************");
                sails.log(m);
                sails.log(m.to);
                sails.log(m.subject);
                sails.log(m.message);
                sails.log("*********************");



                Message.create(m).exec(function (err, _data) {

                    if (err) { return res.serverError(err); }

                    sails.log('Recorded Message::', _data.id);
                    data = _data;

                });
            } else {
                return res.serverError(error);
            }

            return "Message recorded Successfully: " + data.id;

        });
    },

    sendMessage: function testService(_to, _subject, _message, res) {

        if (!_to || !_subject || !_message) {

            sails.log.error("Invalid Message: " +
                " To: " + _to +
                " Subject: " + _subject +
                " Message: " + _message);
            return false;
        }

        var t = send({
            to: _to,
            subject: "[GerPro] " + _subject,
            text: _message
        }, function (err, res) {
            sails.log('*Sending ;;; send(): err:', err, '; res:', res);

            var m = {
                to: _to,
                subject: _subject,
                message: _message
            };

            var data;

            sails.log("*********************");
            sails.log(m);
            sails.log(m.to);
            sails.log(m.subject);
            sails.log(m.message);
            sails.log("*********************");

            Message.create(m).exec(function (err, _data) {

                if (err) { return res.serverError(err); }

                sails.log('Recorded Message::', _data.id);
                data = _data;

            });
            return "Message recorded Successfully: " + data.id;


        });
    }
};

module.exports = MessageServices; 
