
// The procedure is called by the button "Allow editing".
//
&AtClient
Procedure AllowEdit(Command)

	Result = New Array;

	If AllowEditCashAssetsCurrency Then
		Result.Add("CashCurrency");
	EndIf;

	If AllowEditCashCRType Then
		Result.Add("CashCRType");
	EndIf;
	
	If AllowEditingOfStructuralUnit Then
		Result.Add("StructuralUnit");
	EndIf;
	
	If EnableEditDivision Then
		Result.Add("Division");
	EndIf;
	
	Close(Result);

EndProcedure // AllowEdit()



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
