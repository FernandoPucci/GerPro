/**
 * TesteController
 *
 * @description :: Server-side logic for managing testes
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */



module.exports = {

    //não permite delete
    destroy: function (req, res) {
        return res.json(403, 'Sem permissão para apagar');
    },

    //utiliza o TesteService criado
    testeCall: function (req, res) {

        var testeMsg = TesteService.testeFunction();

        res.send('Retorno: ' + testeMsg);

    }
};

