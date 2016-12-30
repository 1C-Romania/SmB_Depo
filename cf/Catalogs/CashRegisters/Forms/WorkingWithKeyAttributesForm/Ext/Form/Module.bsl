
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
	
	If EnableEditDepartment Then
		Result.Add("Department");
	EndIf;
	
	Close(Result);

EndProcedure // AllowEdit()














