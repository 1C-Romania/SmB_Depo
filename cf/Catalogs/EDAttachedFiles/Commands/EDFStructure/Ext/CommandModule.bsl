
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	EDKind = EDAttribute(CommandParameter, "EDKind");
	EDOwner = EDOwner(CommandParameter);
	If IsFTSDocument(EDOwner) Then
		OpenEDTree(CommandParameter, CommandExecuteParameters);
		
	ElsIf EDKind = PredefinedValue("Enum.EDKinds.RandomED") Then
		OpenSubordinationStructure(CommandParameter, CommandExecuteParameters);
		
	Else
		OpenEDList(CommandParameter, CommandExecuteParameters);
		
	EndIf;
	
EndProcedure


// SERVICE PROCEDURES AND FUNCTIONS
//
&AtClient
Procedure OpenEDList(CommandParameter, CommandExecuteParameters)
	
	EDOwner = EDAttribute(CommandParameter, "FileOwner");
	
	ListParameters = WindowOpeningParameters(CommandParameter, CommandExecuteParameters);
	
	ElectronicDocumentsClient.OpenEDList(EDOwner, ListParameters);
	
EndProcedure

&AtClient
Procedure OpenEDTree(CommandParameter, CommandExecuteParameters)
	
	FileOwner = EDAttribute(CommandParameter, "FileOwner");
	
	If Not ValueIsFilled(FileOwner) Then
		Return;
	EndIf;
	
	ListParameters = WindowOpeningParameters(CommandParameter, CommandExecuteParameters);
		
	ElectronicDocumentsClient.OpenEDTree(FileOwner, ListParameters, False);
	
EndProcedure

&AtClient
Function WindowOpeningParameters(CommandParameter, CommandExecuteParameters);
	
	WindowParameters = New Structure;
	WindowParameters.Insert("InitialDocument", CommandParameter);
	WindowParameters.Insert("Source", CommandExecuteParameters.Source);
	WindowParameters.Insert("Window", CommandExecuteParameters.Window);
	WindowParameters.Insert("Uniqueness", CommandParameter);
	
	Return WindowParameters;
	
EndFunction

&AtServer
Function EDOwner(ElectronicDocument)
	
	EDOwner = ?(ValueIsFilled(ElectronicDocument.ElectronicDocumentOwner),
		ElectronicDocument.ElectronicDocumentOwner,
		ElectronicDocument);
	
	If ValueIsFilled(EDOwner.ElectronicDocumentOwner) Then
		Return EDOwner(EDOwner);
	Else
		Return EDOwner;
	EndIf;
	
EndFunction

&AtServer
Function EDAttribute(RefED, AttributeName)
	
	Return CommonUse.ObjectAttributeValue(RefED, AttributeName);
	
EndFunction

&AtServer
Function IsFTSDocument(EDOwner)
	
	EDKind = EDAttribute(EDOwner, "EDKind");
	Return ElectronicDocumentsService.IsFTS(EDKind);
	
EndFunction

&AtClient
Procedure OpenSubordinationStructure(CommandParameter, CommandExecuteParameters)
	
	FileOwner = EDAttribute(CommandParameter, "FileOwner");

	OpenForm("CommonForm.Dependencies",New Structure("FilterObject", FileOwner),
				CommandExecuteParameters.Source,
				CommandExecuteParameters.Source.UniqueKey,
				CommandExecuteParameters.Window);
	
EndProcedure









