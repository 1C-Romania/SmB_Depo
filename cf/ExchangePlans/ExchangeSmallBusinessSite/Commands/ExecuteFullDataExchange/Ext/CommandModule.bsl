
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	MessageText = NStr("en='Warning! Execution of full exchange can take a long time. Continue?';ru='Внимание! Выполнение полного обмена может занять длительное время. Продолжить?'");
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("CommandDataProcessorEnd", ThisObject, New Structure("CommandParameter", CommandParameter)), MessageText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure CommandDataProcessorEnd(Result, AdditionalParameters) Export
    
    CommandParameter = AdditionalParameters.CommandParameter;
    
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    ExchangeNode = CommandParameter;
    
    If ExchangeNode = ExchangeWithSiteReUse.GetThisNodeOfExchangePlan("ExchangeSmallBusinessSite") Then
        CommonUseClientServer.MessageToUser(
        NStr("en='The node corresponds to this infobase and can not be used in exchange with website. Use another exchange node or create the new one.';ru='Узел соответствует этой информационной базе и не может использоваться в обмене с сайтом. Используйте другой узел обмена или создайте новый.'"));
        Return;
    EndIf;
    
    Status(
    StringFunctionsClientServer.SubstituteParametersInString(
    NStr("en='%1 started data exchange with site';ru='%1 начат обмен данными с сайтом'"),
    Format(CurrentDate(), "DLF=DT"))
    ,,
    StringFunctionsClientServer.SubstituteParametersInString(
    NStr("en='by exchange node ""%1""...';ru='по узлу обмена ""%1""...'"),
    ExchangeNode));
    
    ExchangeWithSite.RunExchange(ExchangeNode, NStr("en='Interactive exchange';ru='Интерактивный обмен'"), False);
    
    ShowUserNotification(
    StringFunctionsClientServer.SubstituteParametersInString(
    NStr("en='%1 ""%2""';ru='%1 ""%2""'"),
    Format(CurrentDate(), "DLF=DT"),
    ExchangeNode) 
    ,,
    NStr("en='Exchange with site completed';ru='Обмен с сайтом завершен'"),
    PictureLib.Information32);
    
    Notify("ExchangeWithSiteSessionFinished");
    
EndProcedure



