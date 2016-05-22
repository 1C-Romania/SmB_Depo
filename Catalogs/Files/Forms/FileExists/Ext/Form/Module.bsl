
#Region FormCommandsHandlers

&AtClient
Procedure OverwriteExecute()
	
	ReturnStructure = New Structure("ApplyForAll, ReturnCode", 
		ApplyToAll, DialogReturnCode.Yes);
	Close(ReturnStructure);
	
EndProcedure

&AtClient
Procedure IgnoreExecute()
	
	ReturnStructure = New Structure("ApplyForAll, ReturnCode", 
		ApplyToAll, DialogReturnCode.Ignore);
	Close(ReturnStructure);
	
EndProcedure

&AtClient
Procedure AbortExecute()
	
	ReturnStructure = New Structure("ApplyForAll, ReturnCode", 
		ApplyToAll, DialogReturnCode.Abort);
	Close(ReturnStructure);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetUsageParameters(ParametersStructure) Export
	
	MessageText = ParametersStructure.MessageText;
	ApplyToAll = ParametersStructure.ApplyToAll;
	SetDefaultsButton(ParametersStructure.BaseAction);

EndProcedure

&AtClient
Procedure SetDefaultsButton(DefaultAction)
	
	If DefaultAction = ""
	 Or DefaultAction = DialogReturnCode.Ignore Then
		
		Items.Skip.DefaultButton = True;
		
	ElsIf DefaultAction = DialogReturnCode.Yes Then
		Items.Rewrite.DefaultButton = True;
		
	ElsIf DefaultAction = DialogReturnCode.Abort Then
		Items.Break.DefaultButton = True;
	EndIf;
	
EndProcedure

#EndRegion
