
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	MessageText = NStr("en = 'Warning! Execution of full exchange can take a long time. Continue?'");
	
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
        NStr("en = 'The node corresponds to this infobase and can not be used in exchange with website. Use another exchange node or create the new one.'"));
        Return;
    EndIf;
    
    Status(
    StringFunctionsClientServer.PlaceParametersIntoString(
    NStr("en = '%1 started data exchange with site'"),
    Format(CurrentDate(), "DLF=DT"))
    ,,
    StringFunctionsClientServer.PlaceParametersIntoString(
    NStr("en = 'by exchange node ""%1""...'"),
    ExchangeNode));
    
    ExchangeWithSite.RunExchange(ExchangeNode, NStr("en = 'Interactive exchange'"), False);
    
    ShowUserNotification(
    StringFunctionsClientServer.PlaceParametersIntoString(
    NStr("en = '%1 ""%2""'"),
    Format(CurrentDate(), "DLF=DT"),
    ExchangeNode) 
    ,,
    NStr("en = 'Exchange with site completed'"),
    PictureLib.Information32);
    
    Notify("ExchangeWithSiteSessionFinished");
    
EndProcedure



