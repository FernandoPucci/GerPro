var send = require('gmail-send')({
    user: 'gerpro.noreply@gmail.com', //message sender account
    pass: 'Gerpro123'                 // password
    // html:    '<b>html text text</b>' //HTML body, if necessary
});


var MessageServices = {
    
    sendMessage: function testService(_to, _subject, _message, res) {

        if (!_to || !_subject || !_message) {

            sails.log("Invalid Message: " +
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

            sails.log.info("*********************");
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