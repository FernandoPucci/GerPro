var TestServices = {

    testFunction: function testService() {

        return 'Test Service HealthCheck OK!';

    },

    version: function(req, res){

         TaskChecks.query("SELECT DB_VERSION, CREATED_AT FROM MIGRATIONS WHERE CREATED_AT = (SELECT MAX(CREATED_AT) FROM MIGRATIONS)", function (err, results) {
            if (err)
                return res.serverError(err);
            return res.ok(results.rows);
        });

    }
};

module.exports = TestServices; 