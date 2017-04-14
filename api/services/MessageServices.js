var send = require('gmail-send')({
    user: 'gerpro.noreply@gmail.com', //conta para envio de mensagens
    pass: 'Gerpro123',             // senha
    // html:    '<b>html text text</b>' 
});


var MessageServices = {
    
    sendMessage: function testService(_to, _subject, _message, res) {

        if (!_to || !_subject || !_message) {

            sails.log("Mensagem Inválida: " +
                " To: " + _to +
                " Assunto: " + _subject +
                " Mensagem: " + _message);
                return false; 

        }


        var t = send({
            to: _to,
            subject: _subject,
            text: _message
        }, function (err, res) {
            sails.log('*Enviando ;;; send(): err:', err, '; res:', res);

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

                sails.log('Mensagem gravada:', _data.id);
                data = _data;
            });
            return "Mensagem gravada com sucesso: " + data.id;


        });
    }
};

module.exports = MessageServices; 