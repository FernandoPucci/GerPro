angular.module("mailer").controller("mailerController", function ($scope, $http) {

	$scope.app = "GerPro Mailer Test";

	$scope.enviarMensagem = function () {

		var mens = $scope.mensagem;
		
		// console.log("Mensagem");
		// console.log(mens.para);
		// console.log(mens.assunto);
		// console.log(mens.msg);
		// console.log(mens);
	
		var send = {
						"to":$scope.mensagem.para,
						"subject": $scope.mensagem.assunto,
						"message": $scope.mensagem.msg
					};
	
		$http({
			url: 'message/sendMessage',
			method: 'POST',
			data: send,
			headers: {'Content-Type': 'application/json'}
		});

		$scope.mensagem = [];
	};

});


