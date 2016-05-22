&AtClient
Function MainWindow()
	
	MainWindow = Undefined;
	
	Windows = GetWindows();
	If Windows <> Undefined Then
		For Each Window IN Windows Do
			If Window.Main Then
				MainWindow = Window;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return MainWindow;
	
EndFunction

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("FixedAsset", CommandParameter);
	OpenForm("DocumentJournal.FixedAssetsDocuments.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, MainWindow());
	
EndProcedure
