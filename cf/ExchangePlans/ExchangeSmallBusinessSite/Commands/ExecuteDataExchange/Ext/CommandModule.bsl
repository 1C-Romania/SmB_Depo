
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ExchangeNode = CommandParameter;
	
	If ExchangeNode = ExchangeWithSiteReUse.GetThisNodeOfExchangePlan("ExchangeSmallBusinessSite") Then
		CommonUseClientServer.MessageToUser(
			NStr("en='The node corresponds to this infobase and cannot be used in exchange with the website. Use another exchange node or create a new one.';ru='Узел соответствует этой информационной базе и не может использоваться в обмене с сайтом. Используйте другой узел обмена или создайте новый.'"));
		Return;
	EndIf;
	
	Status(
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 data exchange with the website started';ru='%1 начат обмен данными с сайтом'"),
			Format(CurrentDate(), "DLF=DT"))
		,,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='by exchange node ""%1""...';ru='по узлу обмена ""%1""...'"),
			ExchangeNode));
	
	ExchangeWithSite.RunExchange(ExchangeNode, NStr("en='Interactive exchange';ru='Интерактивный обмен'"));
	
	ShowUserNotification(
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 ""%2""';ru='%1 ""%2""'"),
			Format(CurrentDate(), "DLF=DT"),
			ExchangeNode) 
		,,
		NStr("en='Exchange with website is completed';ru='Обмен с сайтом завершен'"),
		PictureLib.Information32);
		
	Notify("ExchangeWithSiteSessionFinished");
	
EndProcedure
