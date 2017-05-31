
#Region BaseFormsProcedures

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Parent") Then
		Object.Parent = Parameters.Parent;    		
	EndIf;
	NotValidRadioButtons = Object.NotValid;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Object.NotValid = False Then
		Items.Code.Mask = GetAccountMaskAtServer();
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		
		If Object.Parent.IsEmpty() Then
			
			Object.BalanceSide = PredefinedValue("Enum.AccountBalanceSides.DrCr");
			
		Else
			
			SetAttributesFromParentAtServer();
			CurrentItem = Items.Code;
			
		EndIf;
		
		Object.FinancialYearsBegin = CommonAtServer.GetLastFinancialYear();
		FinancialYearsBeginOnChange(Undefined);
		
	EndIf;
	SetDescriptionChoiceList();	
	UpdateDialog();
	
EndProcedure

#EndRegion

#Region StandardCommonCommands

&AtClient
Procedure UpdateDialog()
	
	ReadOnlyStatus = Not Object.Parent.IsEmpty();
	Items.BalanceType.ReadOnly = ReadOnlyStatus;
	Items.Purpose.ReadOnly = ReadOnlyStatus;
	Items.Currency.Enabled = Not ReadOnlyStatus;
	Items.Code.Enabled = Not Object.NotValid;
	
EndProcedure

#EndRegion

#Region ItemsEvents

&AtClient
Procedure ParentOnChange(Item)
	Items.Code.Mask = GetAccountMaskAtServer();
	SetAttributesFromParentAtServer();
	SetDescriptionChoiceList();	
	UpdateDialog();	
EndProcedure

&AtClient
Procedure NotValidRadioButtonsOnChange(Item)
	Object.NotValid = NotValidRadioButtons;
	Items.Code.Enabled = Not Object.NotValid;
	Items.FinancialYearsEnd.Enabled = Object.NotValid;
	If Object.NotValid Then
		Object.FinancialYearsEnd = CommonAtServer.GetLastFinancialYear();
		FinancialYearsEndOnChange(Undefined);
	Else
		Object.FinancialYearsEnd = PredefinedValue("Catalog.FinancialYears.EmptyRef");
	EndIf;
	GenerateCode();
	GenerateAdditionalView();
	Modified=True; 
EndProcedure

&AtClient
Procedure FinancialYearsBeginOnChange(Item)
	FinancialYearsBeginOnChangeAtServer();
EndProcedure

&AtServer
Procedure FinancialYearsBeginOnChangeAtServer()
	If ValueIsFilled(Object.FinancialYearsBegin) Then
		If ValueIsFilled(Object.Ref) Then
			BeginUsingAccount = GetDateUsingAccount(Object.Ref).BeginUsing;
			If ValueIsFilled(BeginUsingAccount) Then
				If Object.FinancialYearsBegin.DateFrom > BeginUsingAccount Then
					Message(Alerts.ParametrizeString(NStr("en='The account is used since %P1!';pl='Konto jest używane od %P1 roku!';ru='Счет уже используется с %P1 года!'"), New Structure("P1", Format(BeginUsingAccount,"DF=yyyy"))), MessageStatus.VeryImportant);
					Object.FinancialYearsBegin = PredefinedValue("Catalog.FinancialYears.EmptyRef");
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	GenerateCode();
	GenerateAdditionalView();	
EndProcedure

&AtClient
Procedure FinancialYearsEndOnChange(Item)
	FinancialYearsEndOnChangeAtServer();
EndProcedure

&AtServer
Procedure FinancialYearsEndOnChangeAtServer()
	If ValueIsFilled(Object.FinancialYearsEnd) Then
		If ValueIsFilled(Object.Ref) Then
			EndUsingAccount = GetDateUsingAccount(Object.Ref).EndUsing;
			If ValueIsFilled(EndUsingAccount) Then
				If Object.FinancialYearsEnd.DateTo < EndUsingAccount Then
					Message(Alerts.ParametrizeString(NStr("en='The account is used to %P1!';pl='Konto jest używane do %P1 roku!';ru='Счет уже используется в %P1 году!'"), New Structure("P1", Format(EndUsingAccount,"DF=yyyy"))), MessageStatus.VeryImportant);
					Object.FinancialYearsEnd = PredefinedValue("Catalog.FinancialYears.EmptyRef");
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	GenerateCode();
	GenerateAdditionalView();	
EndProcedure

&AtClient
Procedure CodeOnChange(Item)
	If Not Object.NotValid Then
		Presentation = Object.Code;
	EndIf;
	GenerateAdditionalView();	
EndProcedure


&AtClient
Procedure PurposeOnChange(Item)
	PurposeOnChangeAtServer();
EndProcedure

&AtServer
Procedure PurposeOnChangeAtServer()
	AccountObject = FormDataToValue(Object, Type("ChartOfAccountsObject.Bookkeeping"));
	AccountObject.SetAttributesByPurpose();
	
	ValueToFormData(AccountObject, Object);
EndProcedure

&AtClient
Procedure CurrencyOnChange(Item)
	UpdateDialog();
	CurrencyOnChangeAtServer();
EndProcedure

&AtServer
Procedure CurrencyOnChangeAtServer()
	// set default value
	For Each Item In Object.ExtDimensionTypes Do
		Item.Currency = Object.Currency;
	EndDo;
EndProcedure

&AtClient
Procedure ExtDimension1TypeOnChange(Item)
	Object.ExtDimension1Mandatory = Not Object.ExtDimension1Type.IsEmpty();
EndProcedure

&AtClient
Procedure ExtDimension1TypeOpening(Item, StandardProcessing)
	StandardProcessing = False;
	OpenExtDimensionValues(Item, Object.ExtDimension1Type);
EndProcedure

&AtClient
Procedure ExtDimension2TypeOnChange(Item)
	Object.ExtDimension2Mandatory = Not Object.ExtDimension2Type.IsEmpty();
EndProcedure

&AtClient
Procedure ExtDimension2TypeOpening(Item, StandardProcessing)
	StandardProcessing = False;
	OpenExtDimensionValues(Item, Object.ExtDimension2Type);
EndProcedure

&AtClient
Procedure ExtDimension3TypeOnChange(Item)
	Object.ExtDimension3Mandatory = Not Object.ExtDimension3Type.IsEmpty();
EndProcedure

&AtClient
Procedure ExtDimension3TypeOpening(Item, StandardProcessing)
	StandardProcessing = False;
	OpenExtDimensionValues(Item, Object.ExtDimension3Type);
EndProcedure

#EndRegion

#Region Other

&AtClient
Procedure OpenExtDimensionValues(Item, SelectedExtDimension)
	
	If ValueIsNotFilled(SelectedExtDimension) Then
		Return;
	EndIf;
		
	TypesValueList = GetTypesValueList(SelectedExtDimension);
	
	If TypesValueList.Count() = 1 Then
		ValueListItem = TypesValueList[0];
		
		ContinueOpenExtDimensionValues(ValueListItem, SelectedExtDimension);
	Else
		Notify	= New NotifyDescription("AfterChooseFromMenu", ThisObject, New Structure("SelectedExtDimension", SelectedExtDimension));
		ShowChooseFromMenu(Notify, TypesValueList);
	EndIf;

EndProcedure

&AtClient
Procedure AfterChooseFromMenu(SelectedItem, AdditionalParameters) Export
	
	ValueListItem = SelectedItem;
	ContinueOpenExtDimensionValues(ValueListItem, AdditionalParameters.SelectedExtDimension)

EndProcedure

&AtClient
Procedure ContinueOpenExtDimensionValues(ValueListItem, SelectedExtDimension) 
	
	If ValueListItem = Undefined Then
		Return;
	EndIf;
	
	ExtDimensionType = ValueListItem.Value;
	
	ListFormName = GetListFormName(SelectedExtDimension, ExtDimensionType);
	
	If ValueIsFilled(ListFormName) Then
		FormParameters = New Structure;
		If ExtDimensionType = Type("CatalogRef.BookkeepingAccountsExtraDimensionsValues") Then
			
			Filter = New Structure;
			Filter.Insert("Owner", SelectedExtDimension);
			FormParameters.Insert("Filter",Filter);
			
		EndIf;		
		OpenForm(ListFormName,FormParameters, ThisForm);
	EndIf;
EndProcedure

&AtServer
Function GetTypesValueList(SelectedExtDimension)
	TypesArray = SelectedExtDimension.ValueType.Types();
	TypesValueList = New ValueList;
	
	For Each ArrayElement In TypesArray Do
		
		ObjectRef = New(ArrayElement);
		
		If Catalogs.AllRefsType().ContainsType(ArrayElement) Then
			ExtDimensionTypePresentation = NStr("en='Catalog';pl='Katalog';ru='Справочник'") + " " + ObjectRef.Metadata().Synonym;
		ElsIf Documents.AllRefsType().ContainsType(ArrayElement) Then
			ExtDimensionTypePresentation = NStr("en='Documents';pl='Dokumenty';ru='Документы'") + " " + ObjectRef.Metadata().Synonym;
		ElsIf Enums.AllRefsType().ContainsType(ArrayElement) Then
			ExtDimensionTypePresentation = NStr("en='Enumeration';pl='Enumeracja';ru='Перечисление'") + " " + ObjectRef.Metadata().Synonym;
		EndIf;
		
		TypesValueList.Add(ArrayElement, ExtDimensionTypePresentation);
		
	EndDo;
	
	Return TypesValueList;
EndFunction

&AtServer
Function GetListFormName(SelectedExtDimension, ExtDimensionType, ListFormName = "")
	ObjectRef = New(ExtDimensionType);
	ObjectName = ObjectRef.Metadata().Name;
	
	If Catalogs.AllRefsType().ContainsType(ExtDimensionType) Then
		ListFormName = "Catalog." + ObjectName + ".ListForm";
	ElsIf Documents.AllRefsType().ContainsType(ExtDimensionType) Then
		ListFormName = "Document." + ObjectName + ".ListForm";
	ElsIf Enums.AllRefsType().ContainsType(ExtDimensionType) Then
		ListFormName = "Enum." + ObjectName + ".ListForm";
	EndIf;
	
	Return ListFormName;
EndFunction

&AtServer
Function GetAccountMaskAtServer()
	AccountObject = FormDataToValue(Object, Type("ChartOfAccountsObject.Bookkeeping"));
	Return AccountObject.GetAccountMask();	
EndFunction

&AtServer
Function GetDateUsingAccount(Account)
	
	ResStructure = New Structure("BeginUsing, EndUsing", Undefined, Undefined);
	
	Query = New Query;
	Query.Text = "SELECT
	             |	MIN(BookkeepingTurnovers.Period) AS BeginUsing,
	             |	MAX(BookkeepingTurnovers.Period) AS EndUsing
	             |FROM
	             |	AccountingRegister.Bookkeeping.Turnovers(, , Month, Account = &Account, , ) AS BookkeepingTurnovers";
	
	Query.SetParameter("Account", Account);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
	
		ResStructure.BeginUsing = Selection.BeginUsing;
		ResStructure.EndUsing = Selection.EndUsing;
	
	EndIf;
	
	Return ResStructure;
	
EndFunction

&AtServer
Procedure SetAttributesFromParentAtServer()
	AccountObject = FormDataToValue(Object, Type("ChartOfAccountsObject.Bookkeeping"));
	AccountObject.SetAttributesFromParent();
	ValueToFormData(AccountObject, Object);
EndProcedure

&AtClient
Procedure CommandAnalyzesUsingAccount(Command)
	If ValueIsFilled(Object.Ref) Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Account", Object.Ref);
		
		If ValueIsFilled(Object.FinancialYearsEnd) Then
			FormParameters.Insert("Date", ObjectsExtensionsAtServer.GetAttributeFromRef(Object.FinancialYearsEnd,"DateTo") + 1);
		Else
			FormParameters.Insert("Date", CurrentDate());
		EndIf;
		
		OpenForm("DataProcessor.AnalyzesUsingAccount.Form", FormParameters, ThisForm, ThisForm);
	EndIf;	
EndProcedure

&AtServer
Procedure GenerateCode()
	If Object.NotValid Then
		StrValue = ?(Left(Object.Code, 1) = "*" , "", "*") + Object.Code;
		If Find(StrValue, " (") > 0 Then
			StrValue = Left(StrValue, Find(StrValue, " (") - 1);
		EndIf;
		StrValue = StrValue + ?(ValueIsFilled(Object.FinancialYearsEnd), " (" + TrimAll(Object.FinancialYearsEnd.Description) + ")","");
		Items.Code.Mask = "";
		Object.Code = StrValue;
		
	Else
		
		Items.Code.Mask = GetAccountMaskAtServer();
		If Left(Object.Code, 1) = "*" Then
			Object.Code = Right(Object.Code, StrLen(Object.Code) - 1);
		EndIf;
		If Find(Object.Code, " (") > 0 Then
			Object.Code = Left(Object.Code, Find(Object.Code, " (") - 1);
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure GenerateAdditionalView()	
	If Left(Object.Code, 1) = "*" Then
		Object.AdditionalView = Right(Object.Code, StrLen(Object.Code) - 1);
	Else
		Object.AdditionalView = Object.Code;
	EndIf;
	
	If Find(Object.AdditionalView, " (") > 0 Then
		Object.AdditionalView = Left(Object.AdditionalView,Find(Object.AdditionalView, " (") - 1);
	EndIf;	
EndProcedure

&AtClient
Procedure SetDescriptionChoiceList()	
	Items.Description.ChoiceList.Clear();
	If Not Object.Parent.IsEmpty() Then
		Items.Description.ChoiceList.Add(CommonAtServer.GetAttribute(Object.Parent,"Description"));
	EndIf;
EndProcedure

#EndRegion