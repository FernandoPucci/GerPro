/*
Call environment variables for set secret configurations

*/
module.exports.environment_config = {


    
    teste: process.env.TESTE_SOMENTE,
    
    mailAPI: process.env.MAIL_API_KEY,    
    mailDomain: process.env.MAIL_API_DOMAIN,
    
    dbHostPRD: process.env.DB_HOST_PRD,
    dbUserPRD: process.env.DB_USER_PRD,
    dbPasswordPRD: process.env.DB_PASSWORD_PRD,
    dbDatabasePRD: process.env.DB_DATABASE_PRD

}