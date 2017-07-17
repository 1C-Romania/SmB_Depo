

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("BookkeepingOperationsTemplates") Then
		BookkeepingOperationsTemplates = Parameters.BookkeepingOperationsTemplates;	
	EndIf;
	
	If Parameters.Property("ChooseDocumentBase") Then
		ChooseDocumentBase = Parameters.ChooseDocumentBase;
	EndIf;
	If Parameters.Property("DocumentBaseTypeDescription") Then
		DocumentBaseTypeDescription = Parameters.DocumentBaseTypeDescription;	
	EndIf;
	

	
	ThisForm.Title = Nstr("en='Bookkeeping operation template parameters';pl='Parametry schematu księgowania'") + ":  " + BookkeepingOperationsTemplates;
	
	FillPropertyValues(ThisForm, Parameters, , "CloseOnChoice, CloseOnOwnerClose, ReadOnly");
	
	For Each ParametersRow In Parameters.ParametersTableArray Do
		NewParametersRow = ParametersTable.Add();
		FillPropertyValues(NewParametersRow, ParametersRow);
	EndDo;
	
	TotalItems = ParametersTable.Count();
	
	For each Row In ParametersTable Do
		
		// NewItem
		ItemName = Row.Name;
		Items.Add(ItemName, Type("FormField"),Items.GroupParameters);
		NewItem = Items[ItemName];
		NewItem.Type = FormFieldType.InputField;
		NewItem.Visible=False;
	

	EndDo;
	

	For each Row In ParametersTable Do

		ParameterDescription     = "";
		ParameterTypeDescription = GetParameterTypeDescription(Row.Name, ParameterDescription);

		TextBox = Items[Row.Name];
		
		If ParameterTypeDescription <> Undefined Then
			
			TextBox.AutoChoiceIncomplete = True;
			Types = ParameterTypeDescription.Types();

			TextBox.ReadOnly     = False;
			TextBox.SkipOnInput = False;						
						
			TextBox.DataPath     = "ParametersTable[" + ParametersTable.IndexOf(Row) + "].Value";
			TextBox.ChooseType  = Types.Count() > 1;
			TextBox.ChoiceButton = True;
			TextBox.DropListButton = False;			
			TextBox.ChoiceButtonRepresentation = ChoiceButtonRepresentation.ShowInDropListAndInInputField;
			
			If Types.Count() = 1 Then

				If Types[0] = Type("String") Then
					TextBox.ChoiceButton = False;
					TextBox.AutoChoiceIncomplete = False;
					TextBox.ChoiceIncomplete     = False;
				EndIf;

			Else
				TextBox.TypeRestriction = ParameterTypeDescription;
			EndIf;

		Else
			TextBox.ReadOnly     	= True;
			TextBox.SkipOnInput 	= True;
			TextBox.ChoiceButton    = False;
			TextBox.ClearButton     = False;
		EndIf;

		TextBox.Title = ParameterDescription.Presentation;
		TextBox.Tooltip            = ParameterDescription.LongDescription;
		TextBox.AutoMarkIncomplete = ParameterDescription.Obligatory;
		
		
		TextBox.SetAction("OnChange", "ParameterOnChange");
		TextBox.SetAction("Clearing", "ParameterClear");
		TextBox.SetAction("ChoiceProcessing", "ChoiceProcessing");
		TextBox.SetAction("StartChoice", "StartChoice");
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	AttachIdleHandler("RefreshFormVisibility",0.1,True);	
EndProcedure

&AtClient
Procedure RefreshFormVisibility()
	For Each Item In ThisForm.Items Do
		If Item.Type = FormFieldType.InputField Then
			Item.Visible=True;		
		EndIf;	
	EndDo;
	
EndProcedure

&AtServer
Function GetResultStructure()
	ResultStructure = New Structure;
	
	ParametersTableArray = New Array;
	For Each ParametersRow In ParametersTable Do
		ParametersTableArray.Add(New Structure("Name,Presentation,Value",ParametersRow.Name,ParametersRow.Presentation,ParametersRow.Value));
	EndDo;	
	ResultStructure.Insert("ParametersTableArray", ParametersTableArray);
	
	Return ResultStructure;
EndFunction

// Returns value of requested parameter by name
//
// Parameters:
//  Name - String - Parameter name
//
// Return Value:
//  Parameter's value 
&AtServer
Function GetParameterValue(Name)

	Return Items[Name].Value;

EndFunction

// Returns TypeDescription of requested parameter
//
// Parameters:
//  Name - String - Parameter name
//  Par - Here will be stored ref on tabular section row
//
// Return Value:
//  TypeDescription of requested parameter 
&AtServer
Function GetParameterTypeDescription(Name, Par = Undefined) 

	If ChooseDocumentBase AND Name = "DocumentBase" Then
		
		Par = New Structure("Obligatory, LongDescription, Presentation", True, Nstr("en='Basis document';pl='Dokument podstawa';ru='Документ-основание'"), Nstr("en='Basis document';pl='Dokument podstawa';ru='Документ-основание'"));
		
		Return DocumentBaseTypeDescription;
		
	EndIf;	
	
	For each Par In BookkeepingOperationsTemplates.Parameters Do

		If Par.Name = Name Then

			If Par.LinkByType = "" Then
				Return Par.Type.Get();
			Else

				ParameterSettingTypeValue = GetParameterValue(Par.LinkByType);
				If ParameterSettingTypeValue = Undefined Then
					Return Undefined
				EndIf;

				Try

					If Par.ExtDimensionNumber > 0 Then
						Return ParameterSettingTypeValue.ExtDimensionTypes[Par.ExtDimensionNumber-1].ExtDimensionType.ValueType;
					Else
						Return ParameterSettingTypeValue.ValueType;
					EndIf;

				Except
					Return Undefined;
				EndTry;

			EndIf;

		EndIf;

	EndDo;

	Message(Nstr("en='In the setting of bookkeeping operation template not found parameter';pl='W ustawieniach schematu księgowania nie został znaleziony parametr'")+":  " + Name);

	Return Undefined;

EndFunction

&AtClient
Procedure ParameterOnChange(Item)
	
EndProcedure // ParameterOnChange() 

&AtClient
Procedure ParameterClear(Item, StandardProcessing)

	//StandardProcessing   = False;
	//ParameterTypeDescription = GetParameterTypeDescription(Item.Name);

	//If ParameterTypeDescription = Undefined Then

	//	Item.Value        = Undefined;
	//	Item.ReadOnly 	  = True;
	//	Item.ChoiceButton = False;
	//	Item.ClearButton  = False;

	//	Return;

	//EndIf;

	//Item.ReadOnly = False;
	//Item.Value    = ParameterTypeDescription.AdjustValue(Undefined);

	//ParameterOnChange(Item);

EndProcedure // ParameterClear() 

&AtClient
Procedure ChoiceProcessing(Item, SelectedValue, StandardProcessing)

	//If TypeOf(SelectedValue) = Type("ValueTableRow") Then

	//	StandardProcessing = False;

	If TypeOf(SelectedValue) = Type("ChartOfAccountsRef.Bookkeeping") Then
		
		StandardProcessing = AccountingAtServer.AccountCanBeUsedInRecords(SelectedValue);

	EndIf;

EndProcedure

&AtClient
Procedure StartChoice(Item, StandardProcessing)

	//ParametersList = New Structure;
	//ParametersList.Insert("Date", CurrentDate());
	//ParametersList.Insert("Account", Undefined);
	//ParametersList.Insert("Item", Undefined);
	//ParametersList.Insert("Warehouse",        Undefined);

	//Accounting.HandleExtDimensionSelection(Item, StandardProcessing, FormOwner.Company, ParametersList);

EndProcedure

&AtClient
Procedure CommandOK(Command)
	If AcceptParameters() Then
		Close(GetResultStructure());	
	EndIf;
EndProcedure

&AtServer
Function AcceptParameters()
	For each Parameter In ParametersTable Do

		ParameterDescription      = Undefined;
		ParameterTypeDescription  = GetParameterTypeDescription(Parameter.Name, ParameterDescription);

		If ParameterDescription.Obligatory AND NOT ValueIsFilled(Parameter.Value) Then

			Message(Nstr("en='Not filled mandatory parameter';pl='Nie został wypełniony obowiązkowy parametr'")+":  " + ParameterDescription.Presentation);
			CurrentItem = Items[Parameter.Name];

			Return False;

		EndIf;

	EndDo;
	Return True;	
EndFunction





