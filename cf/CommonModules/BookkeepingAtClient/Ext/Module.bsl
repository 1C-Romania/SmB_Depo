
#Region ReportsAttributesHandling

Procedure BookkeepingAttributeOnChange(Val ReportName, Val AttributeNameAccount,Form, SettingsComposer,DataCompositionSchemaAdress) Export
	
	If ReportName = "Report.AccountsCard" Then
		
		If AttributeNameAccount = "Account" Then
			BookkeepingAtServer.AccountsCard_UpdateDependencesOnAccount(Form[AttributeNameAccount],SettingsComposer, Form.UUID, DataCompositionSchemaAdress);			
		EndIf;	
		
	ElsIf  ReportName = "Report.TrialBalanceByAccount" Then  
		
		If AttributeNameAccount = "Account" Then  			
			BookkeepingAtServer.TrialBalanceByAccount_UpdateDependencesOnAccount(Form[AttributeNameAccount],SettingsComposer, Form.UUID, DataCompositionSchemaAdress);	 			
		EndIf;
		
	EndIf;	
	
EndProcedure	

#EndRegion
