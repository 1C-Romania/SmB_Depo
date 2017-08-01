
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	//// Wstaw zawartość procedury obsługi zdarzeń.
	////FormParameters = New Structure("", );
	////OpenForm("CommonForm.", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	//#If NOT (ThinClient OR WebClient) Then
	//	If CurrentRunMode() = ClientRunMode.OrdinaryApplication Then
	//		Dialogs.ShowBookkeepingOperation(CommandParameter);
	//	EndIf;		
	//#Else	
		DialogsAtClient.ShowBookkeepingOperation(CommandParameter);		
	//#EndIf
EndProcedure
