////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR DISPLAYING CONTACT INFORMATION ON OBJECT FORMS

// Procedure reads contact information from the information datatbase to the 
// list of data register records.
//
// Parameters:
// RecordSet - list of data register records
// Ref - Object that is filled with contact information
//
Procedure ReadContactInformation(RecordSet, Ref) Export 

	If TypeOf(RecordSet) <> Type("InformationRegisterRecordSet.ContactInformation") Then
		RecordSet = InformationRegisters.ContactInformation.CreateRecordSet();
	Else
		RecordSet.Clear();
	EndIf; 
	
	RecordSet.Filter.Object.Value = Ref;
	RecordSet.Filter.Object.Use   = True;
	RecordSet.Read();
	
	SetTable = RecordSet.Unload();
	SetTable.Sort("ContactInformationType Asc, ContactInformationProfile Asc");
	RecordSet.Load(SetTable);
	
	ArrayProfiles = RecordSet.UnloadColumn("ContactInformationProfile");
	
	Query = New Query;
	
	Query.SetParameter("ContactInformationObjectType", GetContactInformationObjectType(Ref));
	Query.SetParameter("ArrayProfiles"                   , ArrayProfiles);
	
	Query.Text = "SELECT
	             |	ContactInformationProfiles.Ref AS Profile,
	             |	ContactInformationProfiles.ContactInformationType AS Type
	             |FROM
	             |	Catalog.ContactInformationProfiles AS ContactInformationProfiles
	             |WHERE
	             |	ContactInformationProfiles.ContactInformationObjectType = &ContactInformationObjectType
	             |	AND NOT ContactInformationProfiles.Ref IN (&ArrayProfiles)
	             |	AND ContactInformationProfiles.DeletionMark = FALSE
	             |
	             |ORDER BY
	             |	Type,
	             |	Profile";
	
	QuerySelect = Query.Execute().Select();
	While QuerySelect.Next() Do
		RegisterRecord = RecordSet.Add();
		RegisterRecord.ContactInformationProfile = QuerySelect.Profile;
		RegisterRecord.ContactInformationType = QuerySelect.Type;
		RegisterRecord.Object = Ref;
	EndDo; 

EndProcedure

// Procedure writes contact information from the list of data register records 
// to the information datatbase.
//
// Parameters:
// RecordSet - list of data register records
// Ref - Object that contains contact information
// Cancel - boolean
//
Procedure WriteContactInformation(RecordSet, Ref, Cancel, Object = Undefined) Export 
	
	Index = 0;
	While Index < RecordSet.Count() Do
		Record = RecordSet[Index];
		If IsBlankString(Record.Description) Then
			RecordSet.Delete(Record);
			Continue;
		EndIf;
		Record.Object = Ref;
		Index = Index + 1;
	EndDo;
	
	RecordSet.Filter.Object.Set(Ref);
	
	Try
		RecordSet.Write();
	Except
		MessageTitle = NStr("en='The item is not saved:';pl='Nie udało się zapisać elementu katalogu:'") + " " + Ref + ". ";
		MessageText  = NStr("en = 'The contact information is not saved.'; pl = 'Nie udało się zapisać danych kontaktowych.'");
		Alerts.AddAlert(MessageTitle + MessageText + Chars.LF + ErrorInfo().Description,, Cancel, Object);
		Return;
	EndTry;
	
	ReadContactInformation(RecordSet, Ref)
	
EndProcedure

#If Client Then

// Procedure executed on activation of the line in table box, which contains 
// contact information of objects on their forms. Controls availability of the 
// default value button on the control panel.
//
// Parameters:
// Control - TableBox
// ButtonSetBasic - control panel button
//
Procedure ContactInformationOnActivateRowTable(Control, ButtonSetBasic) Export 

	If Control.CurrentData <> Undefined Then
		If Control.CurrentData.DefaultValue Then
			ButtonSetBasic.Check     = True;
			ButtonSetBasic.Enabled = True;
		ElsIf ValueIsNotFilled(Control.CurrentData.Description) Then
			ButtonSetBasic.Check     = False;
			ButtonSetBasic.Enabled = False;
		Else
			ButtonSetBasic.Check     = False;
			ButtonSetBasic.Enabled = True;
		EndIf; 
	Else
		ButtonSetBasic.Check     = False;
		ButtonSetBasic.Enabled = False;
	EndIf; 
	
EndProcedure

// Procedure executed on line output in the table box which contains contact 
// information of objects on their forms.
//
// Parameters:
// Control - TableBox - table box which contains contact information
// RowAppearance - appearance of the line of the table box
// RowData - data on the table box line
//
Procedure ContactInformationListOnRowOutput(Control, RowAppearance, RowData) Export 

	If RowData.DefaultValue Then
		RowAppearance.Font = New Font(,, True);
	EndIf;
	
	If ValueIsNotFilled(RowData.Description) Then
		RowAppearance.TextColor = WebColors.Gray;
	ElsIf TypeOf(RowData.ContactInformationProfile) = Type("String") Then
		RowAppearance.TextColor = StyleColors.InformationTextColor;
	EndIf;
	
	If RowData.ContactInformationType = Enums.ContactInformationTypes.Address Then
		If GetAddressDescription(RowData) = RowData.Description Then
			If ValueIsNotFilled(RowData.Description) Then
				RowAppearance.Cells.Icon.PictureIndex = 8;
			Else
				RowAppearance.Cells.Icon.PictureIndex = 2;
			EndIf; 
		Else
			If ValueIsNotFilled(RowData.Description) Then
				RowAppearance.Cells.Icon.PictureIndex = 7;
			Else
				RowAppearance.Cells.Icon.PictureIndex = 1;
			EndIf; 
		EndIf; 
	ElsIf RowData.ContactInformationType = Enums.ContactInformationTypes.EMail Then
		If ValueIsNotFilled(RowData.Description) Then
			RowAppearance.Cells.Icon.PictureIndex = 9;
		Else
			RowAppearance.Cells.Icon.PictureIndex = 3;
		EndIf; 
	ElsIf RowData.ContactInformationType = Enums.ContactInformationTypes.WWW Then
		If ValueIsNotFilled(RowData.Description) Then
			RowAppearance.Cells.Icon.PictureIndex = 10;
		Else
			RowAppearance.Cells.Icon.PictureIndex = 4;
		EndIf; 
	ElsIf RowData.ContactInformationType = Enums.ContactInformationTypes.Other Then
		If ValueIsNotFilled(RowData.Description) Then
			RowAppearance.Cells.Icon.PictureIndex = 11;
		Else
			RowAppearance.Cells.Icon.PictureIndex = 5;
		EndIf; 
	ElsIf RowData.ContactInformationType = Enums.ContactInformationTypes.Phone Then
		If ValueIsNotFilled(RowData.Description) Then
			RowAppearance.Cells.Icon.PictureIndex = 6;
		Else
			RowAppearance.Cells.Icon.PictureIndex = 0;
		EndIf; 
	EndIf; 

EndProcedure

// BeforeAdd event handler of the list of data register records table box
//
Procedure ContactInformationBeforeAddCommon(Control, Cancel, Clone, mButtonEditContactInformationInDialog, TableBox, ContactInformationSet,FormOwner = Undefined) Export

	If NOT Clone Then
		If mButtonEditContactInformationInDialog.Check Then
			Cancel = True;
			DataProcessors.EditingContactInformation.Create().EditRecord(ContactInformationSet,,FormOwner);
		Else 
			TableBox.Columns.Description.Control.TextEdit = True;
		EndIf;
	Else
		If mButtonEditContactInformationInDialog.Check Then
			Cancel = True;
			DataProcessors.EditingContactInformation.Create().EditRecord(ContactInformationSet,,FormOwner, GetRegisterRecordStructure(TableBox.CurrentData));
		Else
			SetPossibilityEditingTextContactInformation(TableBox);
		EndIf;
	EndIf; 

EndProcedure

// BeforeChange event handler of the list of data register records table box
//
Procedure ContactInformationBeforeChangeCommon(Control, Cancel, mButtonEditContactInformationInDialog,FormOwner = Undefined) Export 

	If mButtonEditContactInformationInDialog.Check Then
		Cancel = True;
		Processing = DataProcessors.EditingContactInformation.Create();
		Processing.EditRecord(Control.CurrentData,,FormOwner);
	Else
		SetPossibilityEditingTextContactInformation(Control);
	EndIf;

EndProcedure

// Procedure sets the primary contact in the ContactInformation data register.
//
// Parameters:
// ParametersStructure - Structure - records for which primary contact is set
//
// Keys:
// Object, ObjectRef, Object dimension value in the data register
// Type - EnumRef.ContactInformationTypes - contact information type
// Profile - CatalogRef.ContactInformationProfiles, String
//
Procedure MarkRecordAsDefault(RecordsSet, TableBox, Button) Export 

	If TableBox.CurrentData <> Undefined
	   AND ValueIsFilled(TableBox.CurrentData.Description) Then
	
		If TableBox.CurrentData.DefaultValue Then
		
			TableBox.CurrentData.DefaultValue = False;
			Button.Check = False;
			
		Else
			
			For Each Record In RecordsSet Do
				If Record.ContactInformationType = TableBox.CurrentData.ContactInformationType Then
					Record.DefaultValue = False;
				EndIf; 
			EndDo;
			
			TableBox.CurrentData.DefaultValue = True;
			Button.Check = True;
		
		EndIf; 
	
	EndIf;
	
EndProcedure

// BeforeDelete event handler of the list of data register records table box.
//
// Parameters:
// Control - table box
// Cancel - boolean
//
Procedure DeleteContactInformationRecord(Control, Cancel) Export  

	Cancel = True;
	
	If Control.CurrentData <> Undefined And (ValueIsFilled(Control.CurrentData.Description) OR TypeOf(Control.CurrentData.ContactInformationProfile) = Type("String")) Then
	
		AnswerToQuestion = DoQueryBox(Nstr("en='Delete record?';pl='Czy usunąć zapis?'"), QuestionDialogMode.YesNo);
		If AnswerToQuestion <> DialogReturnCode.Yes Then
			Return;
		EndIf;
		
		If TypeOf(Control.CurrentData.ContactInformationProfile) = Type("String") Then
			Control.Value.Delete(Control.CurrentData);
		Else
			Control.CurrentData.Description       = "";
			Control.CurrentData.DefaultValue = False;
		EndIf;
		
	EndIf;

EndProcedure

// Function creates the register record structure.
//
// Parameters:
// Record - list of data register records item
//
Function GetRegisterRecordStructure(Record) Export

	If TypeOf(Record) = Type("InformationRegisterRecord.ContactInformation")
	 OR TypeOf(Record) = Type("InformationRegisterRecordManager.ContactInformation") Then
		RecordStructure = New Structure;
		RecordStructure.Insert("Object"     , Record.Object);
		RecordStructure.Insert("Type"       , Record.ContactInformationType);
		RecordStructure.Insert("Profile"    , Record.ContactInformationProfile);
		RecordStructure.Insert("Description", Record.Description);
		RecordStructure.Insert("Comment", Record.Comment);
		For a = 1 To 9 Do
			RecordStructure.Insert("Field" + String(a), Record["Field" + String(a)]);
		EndDo;
		Return RecordStructure;
	Else
		Return Undefined;
	EndIf; 

EndFunction

//Procedure controls possibility of editing text in the contact information control.
//
Procedure SetPossibilityEditingTextContactInformation(Control) Export

	If Control.CurrentData.ContactInformationType = Enums.ContactInformationTypes.Address
	   And ValueIsFilled(Control.CurrentData.Description)
	   And (GetAddressDescription(Control.CurrentData) = Control.CurrentData.Description) Then
		Control.Columns.Description.Control.TextEdit = False;
	Else
		Control.Columns.Description.Control.TextEdit = True;
	EndIf;

EndProcedure

// OnStartEdit event handler of the list of data register records table box
//
Procedure ContactInformationOnStartEditCommon(Control, NewRow) Export 

	If NewRow Then
		If ValueIsNotFilled(Control.CurrentData.ContactInformationType) Then
			Control.CurrentData.ContactInformationType = Enums.ContactInformationTypes.Address;
		EndIf; 
		If ValueIsNotFilled(Control.CurrentData.ContactInformationProfile) Then
			Control.CurrentData.ContactInformationProfile = Catalogs.ContactInformationProfiles.EmptyRef();
		EndIf; 
	EndIf; 
	
EndProcedure

// BeforeEditEnd event handler of the list of data register records table box
//
Procedure ContactInformationBeforeEditEndCommon(Control, NewRow, CancelEdit, Cancel, mTextTypingTypeContactInformation, mProcessingTypingTypeContactInformation) Export
	
	If mProcessingTypingTypeContactInformation AND NOT NewRow Then
		mProcessingTypingTypeContactInformation = False;
		Cancel = True;
		Control.CurrentColumn = Control.Columns.ContactInformationProfile;
		Control.Columns.ContactInformationProfile.Control.SelectedText = mTextTypingTypeContactInformation;
		mTextTypingTypeContactInformation = "";
	EndIf;
	
EndProcedure

// OnChange event handler of contact information representation of the list of 
// data register records table box.
//
Procedure ContactInformationDescriptionOnChangeCommon(Control, TableBox) Export 

	If TableBox.CurrentData.ContactInformationType = Enums.ContactInformationTypes.Phone Then
		
		FieldsStructure = GetPhoneNumberFields(Control.Value);
		TableBox.CurrentData.Field3 = FieldsStructure.ThisPhone;
		TableBox.CurrentData.Field1 = FieldsStructure.CountryCode;
		TableBox.CurrentData.Field2 = FieldsStructure.CityCode;
		
		GeneratePhoneNumberDiscription(TableBox.CurrentData);
		
	EndIf;
	
EndProcedure

// OnChange event handler of contact information type of the list of data 
// register records table box.
//
Procedure ContactInformationContactInformationTypeOnChangeCommon(Control, TableBox) Export 

	If TypeOf(TableBox.CurrentData) = Type("InformationRegisterRecord.ContactInformation")
	   AND ValueIsFilled(TableBox.CurrentData.ContactInformationProfile)
	   AND TypeOf(TableBox.CurrentData.ContactInformationProfile) = Type("CatalogRef.ContactInformationProfiles")
	   AND TableBox.CurrentData.ContactInformationProfile.ContactInformationType <> Control.Value Then
	
		TableBox.CurrentData.ContactInformationProfile = Catalogs.ContactInformationProfiles.EmptyRef();
	
	EndIf; 

EndProcedure

#EndIf
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR HANDLING FORMS OF THE CONTACT INFORMATION KEEPING SYSTEM

// Returns an empty value of the type according to the contact information object type
//
// Parameters:
// CIObjectType - Enums.ContactInformationObjectTypes
//
// Returns:
// CatalogRef (empty) or Undefined
//
Function GetEmptyValueContactInformationObject(ContactInformationObjectType) Export 
	
	If ContactInformationObjectType = Enums.ContactInformationObjectTypes.ContactPersons Then
		Return Catalogs.ContactPersons.EmptyRef();
	ElsIf ContactInformationObjectType = Enums.ContactInformationObjectTypes.Banks Then
		Return Catalogs.Banks.EmptyRef();
	ElsIf ContactInformationObjectType = Enums.ContactInformationObjectTypes.Companies Then
		Return Catalogs.Companies.EmptyRef();
	ElsIf ContactInformationObjectType = Enums.ContactInformationObjectTypes.Customers Then
		Return Catalogs.Customers.EmptyRef();
	ElsIf ContactInformationObjectType = Enums.ContactInformationObjectTypes.Suppliers Then
		Return Catalogs.Suppliers.EmptyRef();
	ElsIf ContactInformationObjectType = Enums.ContactInformationObjectTypes.Employees Then
		Return Catalogs.Employees.EmptyRef();
	Else 
		Return Undefined;
	EndIf;
	
EndFunction 

// Function determins the type of contact information object
//
// Parameters:
// ObjectRef - contact information object pointer
//
// Returns:
// Pointer to the ContactInformationObjectTypes enumaration which corresponds to the ObjectRef
//
Function GetContactInformationObjectType(ObjectRef) Export

	If ObjectRef = Undefined Then
		Return Enums.ContactInformationObjectTypes.EmptyRef();
	ElsIf TypeOf(ObjectRef) = Type("CatalogRef.Banks") Then
		Return Enums.ContactInformationObjectTypes.Banks;
	ElsIf TypeOf(ObjectRef) = Type("CatalogRef.Departments") Then
		Return Enums.ContactInformationObjectTypes.Departments; 	
	ElsIf TypeOf(ObjectRef) = Type("CatalogRef.Suppliers") Then
		Return Enums.ContactInformationObjectTypes.Suppliers;
	ElsIf TypeOf(ObjectRef) = Type("CatalogRef.Companies") Then
		Return Enums.ContactInformationObjectTypes.Companies;
	ElsIf TypeOf(ObjectRef) = Type("CatalogRef.Customers") Then
		Return Enums.ContactInformationObjectTypes.Customers; 
	ElsIf TypeOf(ObjectRef) = Type("CatalogRef.ContactPersons") Then
		Return Enums.ContactInformationObjectTypes.ContactPersons;
	ElsIf TypeOf(ObjectRef) = Type("CatalogRef.Users") Then
		Return Enums.ContactInformationObjectTypes.Users;	
	ElsIf TypeOf(ObjectRef) = Type("CatalogRef.Employees") Then
		Return Enums.ContactInformationObjectTypes.Employees;
	ElsIf TypeOf(ObjectRef) = Type("CatalogRef.WarehouseLocalizations") Then
		Return Enums.ContactInformationObjectTypes.WarehouseLocalizations; 	
	ElsIf TypeOf(ObjectRef) = Type("CatalogRef.InlandRevenues") Then
		Return Enums.ContactInformationObjectTypes.InlandRevenues; 	
	Else
		Return Enums.ContactInformationObjectTypes.EmptyRef();
	EndIf; 
	
EndFunction 

// Function is called at the beginning of contact information object selection
// Parameters:
//
// WriteForm - form of the ContactInformation data register record
// Control - form element of the ContactInformation data register record, which is selected.
//
// Returns:
// Boolean - continue standard selection procedure.
//	
Function ObjectContactInformationStartChoice(WriteForm, Control) Export

	If Control.Value <> Undefined Then
		Return True;
	EndIf; 
	
	ObjectsTypesList = New ValueList;

	TypesArea = ?(Control.TypeRestriction.Types().Count() > 0, Control.TypeRestriction.Types(), Control.ValueType.Types());
	For Each Type In TypesArea Do
		NewType = New(Type);
		ObjectsTypesList.Add(NewType.Ref.Metadata().Name, NewType.Ref.Metadata().Synonym);
	EndDo;

	If ObjectsTypesList.Count() = 1 Then
		SelectedListValue = ObjectsTypesList[0];
	Else 
		SelectedListValue = WriteForm.ChooseFromList(ObjectsTypesList, Control);
	EndIf;
	
	if SelectedListValue = Undefined Then
		Return False;
	Else 
		Control.Value = Catalogs[SelectedListValue.Value].EmptyRef();
		Return True;
	EndIf;

EndFunction

// Function returns address representation collected from Field1 - Field10 values
//
// Parameters:
// None
//
// Returns:
// String
//
Function GetAddressDescription(Record) Export 

	CurrPresentation = "";

	If Not IsBlankString(Record.Field1) Then
		CurrPresentation = CurrPresentation + ", " +TrimAll(Record.Field1);
	EndIf;

	If Not IsBlankString(Record.Field2) Then
		CurrPresentation = CurrPresentation + ", " + TrimAll(Record.Field2);
	EndIf;

	If Not IsBlankString(Record.Field3) Then
		CurrPresentation = CurrPresentation + ", " + TrimAll(Record.Field3);
	EndIf;

	If Not IsBlankString(Record.Field4) Then
		CurrPresentation = CurrPresentation + ", " + TrimAll(Record.Field4);
	EndIf;

	If Not IsBlankString(Record.Field5) Then
		CurrPresentation = CurrPresentation + ", " + TrimAll(Record.Field5);
	EndIf;

	If Not IsBlankString(Record.Field6) And Constants.UseRegionInAddressDescription.Get() Then
		CurrPresentation = CurrPresentation + ", " + TrimAll(Record.Field6);
	EndIf;

	If ValueIsFilled(Record.Field7) Then
		CurrPresentation = CurrPresentation + ", " + TrimAll(Record.Field7);
	EndIf;	

	If StrLen(CurrPresentation) > 2 Then
		CurrPresentation = Mid(CurrPresentation, 3);
	EndIf;
	
	Return CurrPresentation;

EndFunction

#If Client Then

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR HANDLING FORMS OF THE CONTACT INFORMATION KEEPING SYSTEM

// Procedure opens the ContactInformationProfiles catalog form for selection.
//
// Parameters:
// ChoiceMode - boolean - form selection mode.
// FormOwner - form from which procedure is called.
// ChoiceValueByType - selection by contact information type.
// ChoiceValueByKindCI - selection by contact information object type.
//
Procedure OpenContactInformationProfileChoiceForm(ChoiceMode, FormOwner, FilterByContactInformationType = Undefined,
                                     FilterByContactInformationObjectType = Undefined) Export

	SelForm = Catalogs.ContactInformationProfiles.GetForm("ListForm", FormOwner);
	SelForm.ChoiceMode = ChoiceMode;
	
	If FilterByContactInformationType <> Undefined Then
		SelForm.Filter.ContactInformationType.Value = FilterByContactInformationType;
		SelForm.Filter.ContactInformationType.Use = True;
		SelForm.Controls.CatalogList.FilterSettings.ContactInformationType.Enabled = False;
	EndIf; 
	
	If FilterByContactInformationObjectType <> Undefined Then
		SelForm.Filter.ContactInformationObjectType.Value = FilterByContactInformationObjectType;
		SelForm.Filter.ContactInformationObjectType.Use = True;
		SelForm.Controls.CatalogList.FilterSettings.ContactInformationObjectType.Enabled = False;
	EndIf;
	
	If TypeOf(FormOwner.Value) = Type("CatalogRef.ContactInformationProfiles")
	   AND ValueIsFilled(FormOwner.Value) Then
		SelForm.CurrentLineParameter = FormOwner.Value;
	EndIf; 
	
	SelForm.Open();
	
EndProcedure

#EndIf

////////////////////////////////////////////////////////////////////////////////
// GENERAL PROCEDURES AND FUNCTIONS

// Procedure forms a string representation of address
//
Procedure GeneratePhoneNumberDiscription(FieldSet) Export
	// Field1      - country code
	// Field2      - city code
	// Field3      - phone number itself
	// Field4      - external
	// Description - formed presentation of phone number with all details

	// Add country code
	FieldSet.Description = FieldSet.Field1;
	
	// Add city code (parenthetical)
	FieldSet.Description = FieldSet.Description + ?((NOT IsBlankString(FieldSet.Field2)),(StringFunctionsClientServer.AddStringSeparator(FieldSet.Description, "")+"(" + FieldSet.Field2 + ")"),"");
	
	// Add phone number
	FieldSet.Description = FieldSet.Description + ?((NOT IsBlankString(FieldSet.Field3)),(StringFunctionsClientServer.AddStringSeparator(FieldSet.Description, "") + ReducePhoneNumberToTemplate(FieldSet.Field3)),"");
	
	// Add "ext." suffix or set it as the main number if other fields were empty
	If NOT IsBlankString(FieldSet.Description) Then
		FieldSet.Description = FieldSet.Description + ?((NOT IsBlankString(FieldSet.Field4)),(StringFunctionsClientServer.AddStringSeparator(FieldSet.Description) + "ext. " + ReducePhoneNumberToTemplate(FieldSet.Field4)),"");
	Else
		FieldSet.Description = ReducePhoneNumberToTemplate(FieldSet.Field4);
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OTHER PROCEDURES AND FUNCTIONS

// Function decomposes a phone number by fields to store in a contact information object
// 
// Parameters:
// PhoneNumber - string - phone number to be decomposed
// 
// Returns:
// Structure
//
Function GetPhoneNumberFields(PhoneNumber) Export 

	CountryCode = "";
	CountryCodeBeginning = Find(PhoneNumber, "+");
	If CountryCodeBeginning > 0 Then
		For a = (CountryCodeBeginning + 1) To StrLen(PhoneNumber) Do
			If Mid(PhoneNumber, a, 1) = " " Then
				Break;
			EndIf; 
			CountryCode = CountryCode + Mid(PhoneNumber, a, 1);
		EndDo; 
	EndIf; 
	CountryCode = TrimAll(CountryCode);

	CityCode = "";
	If StrOccurenceCount(PhoneNumber, "(") = 1 AND StrOccurenceCount(PhoneNumber, ")") = 1 Then
		CityCodeBeginning = Find(PhoneNumber, "(");
		CityCodeEnd = Find(PhoneNumber, ")");
		If CityCodeEnd > CityCodeBeginning Then
			CityCode = Mid(PhoneNumber, (CityCodeBeginning + 1), (CityCodeEnd - CityCodeBeginning - 1));
		EndIf;
	EndIf;
	CityCode = TrimAll(CityCode);

	ThisPhone = PhoneNumber;
	If NOT IsBlankString(CountryCode) Then
		ThisPhone = StrReplace(ThisPhone, ("+" + CountryCode), "");
		ThisPhone = TrimAll(ThisPhone);
	EndIf; 
	If NOT IsBlankString(CityCode) Then
		ThisPhone = StrReplace(ThisPhone, ("(" + CityCode + ")"), "");
		ThisPhone = TrimAll(ThisPhone);
	EndIf;
	
	a = 1;
	While a <= StrLen(ThisPhone) Do
		If (CharCode(Mid(ThisPhone, a, 1)) >= 48 AND CharCode(Mid(ThisPhone, a, 1)) <= 57) OR CharCode(Mid(ThisPhone, a, 1)) = 32 Then
			a = a + 1;
			Continue;
		EndIf;
		ThisPhone = Mid(ThisPhone, 1, (a - 1)) + Mid(ThisPhone, (a + 1));
	EndDo; 

	If NOT IsBlankString(CountryCode) AND Left(TrimL(CountryCode), 1) <> "+" Then
		CountryCode = TrimAll(CountryCode);
		While Left(CountryCode, 1) = "0" Do
			CountryCode = Mid(CountryCode, 2);
		EndDo;
		If NOT IsBlankString(CountryCode) Then
			CountryCode = "+" + CountryCode;
		EndIf; 
	EndIf; 
	
	PhoneFieldsStructure = New Structure("CountryCode,CityCode,ThisPhone", CountryCode, CityCode, ReducePhoneNumberToTemplate(ThisPhone));
	
	Return PhoneFieldsStructure;

EndFunction

// Function formats a phone number with one of setup templates
//
// Parameters:
// PhoneNumber – string - phone number to be formatted
//
// Returns:
// Formatted phone number - string
//
Function ReducePhoneNumberToTemplate(PhoneNumber) Export
	
	PhoneNumberFiguresOnly = "";
	PhoneNumberFiguresQuantity = 0;
	
	For a=1 To StrLen(PhoneNumber) Do
		If StrOccurenceCount("1234567890",Mid(PhoneNumber,a,1)) > 0 Then
			PhoneNumberFiguresQuantity = PhoneNumberFiguresQuantity + 1;
			PhoneNumberFiguresOnly = PhoneNumberFiguresOnly + Mid(PhoneNumber,a,1);
		EndIf;
	EndDo;
	
	If PhoneNumberFiguresQuantity = 0 Then
		Return PhoneNumber;
	EndIf;
	
	TemplatesStructure = Constants.PhoneNumbersFormatStrings.Get().Get();
	If TypeOf(TemplatesStructure) <> Type("Map") Then
		Return PhoneNumber;
	EndIf; 
	
	PhoneNumberTemplate = TemplatesStructure.Get(PhoneNumberFiguresQuantity);
	
	If PhoneNumberTemplate = Undefined Then
		Return PhoneNumber;
	EndIf;
	
	AdjNumber = "";
	FigureNumber = 0;
	
	For a=1 To StrLen(PhoneNumberTemplate) Do
		If Mid(PhoneNumberTemplate,a,1) = "9" Then
			FigureNumber = FigureNumber + 1;
			AdjNumber = AdjNumber + Mid(PhoneNumberFiguresOnly,FigureNumber,1);
		Else
			AdjNumber = AdjNumber + Mid(PhoneNumberTemplate,a,1);
		EndIf;
	EndDo; 

	Return AdjNumber;
	
EndFunction 

// Procedure creates a selection list of contact information by the control 
// object of the document form.
//
// Parameters:
// Control - control for which the list is created.
// Object - Catalof.Suppliers, Catalog.Customers - object by which information 
// is selected from the ContactInformation register.
// Type - Enums.ContactInformationTypes - contact information type.
//
Procedure GenerateContactInformationChoiceList(Control,Object,Type) Export
	
	ValueList = New ValueList;
	Select = GetContactInformation(Object, Type);
	
	While Select.Next() Do
		ValueList.Add(Select.Description);
	EndDo;
	
	Control.ChoiceList = ValueList;
	
EndProcedure

Function GetContactInformation(Object, Type, Profile = Undefined) Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	ContactInformation.Description,
	             |	ContactInformation.ContactInformationProfile,
	             |	ContactInformation.Field1,
	             |	ContactInformation.Field2,
	             |	ContactInformation.Field3,
	             |	ContactInformation.Field4,
	             |	ContactInformation.Field5,
	             |	ContactInformation.Field6,
	             |	ContactInformation.Field7
	             |FROM
	             |	InformationRegister.ContactInformation AS ContactInformation
	             |WHERE
	             |	ContactInformation.Object = &Object
	             |	AND ContactInformation.ContactInformationType = &ContactInformationType";
	
	Query.SetParameter("ContactInformationType", Type);
	Query.SetParameter("Object", Object);
	
	If Profile <> Undefined Then
		Query.Text = Query.Text + "
		                          |	AND ContactInformation.ContactInformationProfile = &ContactInformationProfile";
		Query.SetParameter("ContactInformationProfile", Profile);
	EndIf;
	
	Return Query.Execute().Select();
	
EndFunction

Function GetContactInformationDescription(Object, Type, Profile) Export
	
	Selection = GetContactInformation(Object, Type, Profile);
	If Selection.Next() Then
		Return Selection.Description;
	Else
		Return "";
	EndIf;
	
EndFunction // GetContactInformationDescription()

Function GetContactPersonPhonesString(ContactPersonsCurrentData) Export 
	
	ContactString = "";
	
	If ContactPersonsCurrentData <> Undefined And Not ContactPersonsCurrentData.Ref.IsEmpty() Then
		
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		             |	ContactInformation.Description,
		             |	ContactInformation.ContactInformationProfile
		             |FROM
		             |	InformationRegister.ContactInformation AS ContactInformation
		             |WHERE
		             |	ContactInformation.Object = &Object
		             |	AND ContactInformation.ContactInformationType IN (VALUE(Enum.ContactInformationTypes.Phone), VALUE(Enum.ContactInformationTypes.Email))
		             |
		             |ORDER BY
		             |	ContactInformation.DefaultValue DESC";
		
		Query.SetParameter("Type", Enums.ContactInformationTypes.Phone);
		Query.SetParameter("Object", ContactPersonsCurrentData.Ref);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			ContactString = ContactString + ", " + Selection.ContactInformationProfile + ": " + Selection.Description;
		EndDo;
		
	EndIf;
	
	If IsBlankString(ContactString) Then
		ContactString = NStr("en = '<No contact information>'; pl = '<Brak danych kontaktowych>'");
	Else
		ContactString = Mid(ContactString, 3);
	EndIf;
	
	Return ContactString;
	
EndFunction

#If Client Then

Procedure SelectCustomersAddress(Object,Customer, Control) Export 
	
	If Customer.IsEmpty() Then
		ShowMessageBox(, NStr("en='Please, first input customer.';pl='Najpierw wprowadź klienta.'"));
		Return;
	EndIf;
	
	SelectAddress(Object,Customer, Control);
	
EndProcedure // SelectCustomersAddress()

Procedure SelectSuppliersAddress(Object,Supplier, Control) Export 
	
	If Supplier.IsEmpty() Then
		ShowMessageBox(, NStr("en='Please, first input supplier.';pl='Najpierw wprowadź dostawcę.'"));
		Return;
	EndIf;
	
	SelectAddress(Object,Supplier, Control);
	
EndProcedure // SelectSuppliersAddress()

Procedure SelectCompanyAddress(Object,Company, Control) Export 
	
	If Company.IsEmpty() Then
		ShowMessageBox(, NStr("en='Please, first input company.';pl='Najpierw wprowadź firmę.'"));
		Return;
	EndIf;
	
	SelectAddress(Object,Company, Control);
	
EndProcedure // SelectCompanyAddress()

Procedure SelectAddress(Object,BusinessPartner, Control)
	
	If Object = Undefined Then
		Return;
	EndIf;
	
	ObjectMetadata = Object.Metadata();
	
	AddressSelectorForm = DataProcessors.AddressSelector.GetForm("AddressSelectionForm", Control, Control);
	AddressSelectorForm.Object = BusinessPartner;
	
	If CommonAtServer.IsDocumentAttribute("DeliveryPointAddress", ObjectMetadata) Then
		AddressSelectorForm.Description = Object.DeliveryPointAddress;
	EndIf;
	
	If CommonAtServer.IsDocumentAttribute("Field1", ObjectMetadata) Then
		AddressSelectorForm.Field1 = Object.Field1;
	EndIf;
	
	If CommonAtServer.IsDocumentAttribute("Field2", ObjectMetadata) Then
		AddressSelectorForm.Field2 = Object.Field2;
	EndIf;
	
	If CommonAtServer.IsDocumentAttribute("Field3", ObjectMetadata) Then
		AddressSelectorForm.Field3 = Object.Field3;
	EndIf;
	
	If CommonAtServer.IsDocumentAttribute("Field4", ObjectMetadata) Then
		AddressSelectorForm.Field4 = Object.Field4;
	EndIf;
	
	If CommonAtServer.IsDocumentAttribute("Field5", ObjectMetadata) Then
		AddressSelectorForm.Field5 = Object.Field5;
	EndIf;
	
	If CommonAtServer.IsDocumentAttribute("Field6", ObjectMetadata) Then
		AddressSelectorForm.Field6 = Object.Field6;
	EndIf;
	
	If CommonAtServer.IsDocumentAttribute("Field7", ObjectMetadata) Then
		AddressSelectorForm.Field7 = Object.Field7;
	EndIf;
	
	AddressSelectorForm.Open();
	
	
	
EndProcedure // SelectAddress()

Function GetAddressUnitsList(UnitName) Export
	
	ValueList = New ValueList;
	
	Template = GetCommonTemplate("AddressUnits");
	AddressUnits = Template.GetArea(UnitName);
	
	For x = 1 to AddressUnits.TableHeight Do
		
		Presentation = AddressUnits.Area(x, 1, x, 1).Text;
		
		Structure = New Structure;
		
		If UnitName = "Cities" Then
			Structure.Insert("Region",  AddressUnits.Area(x, 2, x, 2).Text);
			Structure.Insert("Country", AddressUnits.Area(x, 3, x, 3).Text);
		ElsIf UnitName = "Regions" Then
			Structure.Insert("Country", AddressUnits.Area(x, 2, x, 2).Text);
		EndIf;
		
		ValueList.Add(Structure, Presentation);
		
	EndDo;
	
	ValueList.SortByPresentation();
	
	Return ValueList.ChooseItem();
	
EndFunction // GetAddressUnitsList()

#EndIf

Procedure ClearAddressForObject(Data) Export
	
	Data.DeliveryPointAddress = "";
	Data.Field1 = "";
	Data.Field2 = "";
	Data.Field3 = "";
	Data.Field4 = "";
	Data.Field5 = "";
	Data.Field6 = "";
	Data.Field7 = "";
	
EndProcedure	
	
Procedure FillAddressForObjectFromSelector(ChoiceValue, Data) Export
	
	Data.DeliveryPointAddress = ChoiceValue.Description;
	Data.Field1 = ChoiceValue.Field1;
	Data.Field2 = ChoiceValue.Field2;
	Data.Field3 = ChoiceValue.Field3;
	Data.Field4 = ChoiceValue.Field4;
	Data.Field5 = ChoiceValue.Field5;
	Data.Field6 = ChoiceValue.Field6;
	Data.Field7 = ChoiceValue.Field7;
	
EndProcedure

Procedure SetDeliveryPointAddress(DeliveryPoint, ContactInformationTypes, DeliveryAddress,Data) Export
	
	AddressSelection = GetContactInformation(DeliveryPoint, ContactInformationTypes, DeliveryAddress);
	AddressSelection.Next();
	FillAddressForObjectFromSelector(AddressSelection,Data);
	
EndProcedure	

Function GetListOfPostalCodesByAddress(ShowNumbers = False,Region = "", City = "", Street = "") Export
	
	ReturnValueList = New ValueList;
	
	Query = New Query();
	Query.Text = "SELECT DISTINCT
	             |	Poland_AddressClassifier.PostalCode " + ?(ShowNumbers,", Poland_AddressClassifier.Numbers","") + "
	             |FROM
	             |	InformationRegister.Poland_AddressClassifier AS Poland_AddressClassifier";
				 
	IsWhere = False;
	WhereText = "";
	
	If NOT IsBlankString(Region) Then
		If IsWhere Then
			WhereText = WhereText + " AND ";
		EndIf;	
		WhereText = WhereText + "Poland_AddressClassifier.Region = &Region";
		IsWhere = True;
	EndIf;	
	If NOT IsBlankString(City) Then
		If IsWhere Then
			WhereText = WhereText + " AND ";
		EndIf;	
		WhereText = WhereText + "Poland_AddressClassifier.City = &City";
		IsWhere = True;
	EndIf;	
	If NOT IsBlankString(City) Then
		If IsWhere Then
			WhereText = WhereText + " AND ";
		EndIf;	
		WhereText = WhereText + "Poland_AddressClassifier.Street = &Street";
		IsWhere = True;
	EndIf;	
	If IsWhere Then
		Query.Text = Query.Text + " WHERE " + WhereText;
	EndIf;
	Query.SetParameter("Region",Region);
	Query.SetParameter("City",City);
	Query.SetParameter("Street",Street);
	QueryResult = Query.Execute();
	If ShowNumbers Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			ReturnValueList.Add(Selection.PostalCode,Selection.PostalCode + ?(IsBlankString(Selection.Numbers),""," (" + Selection.Numbers + ")"));
		EndDo;	
		ReturnValueList.SortByPresentation();
	Else	
		ReturnValueList.LoadValues(QueryResult.Unload().UnloadColumn("PostalCode"));
		ReturnValueList.SortByValue();
	EndIf;	
	
	Return ReturnValueList;
	
EndFunction		

Function GetPostalCodeIfOne(ShowNumbers = False,Region = "", City = "", Street = "") Export
	
	ValueList = GetListOfPostalCodesByAddress(ShowNumbers,Region, City, Street);
	If ValueList.Count() = 1 Then
		Return ValueList[0].Value;
	EndIf;
	
EndFunction	

Function ChoosePostalCodeByAddress(ShowNumbers = False,Region = "", City = "", Street = "") Export
	
	ValueList = GetListOfPostalCodesByAddress(ShowNumbers,Region, City, Street);
	Return ValueList.ChooseItem();
	
EndFunction	

Function GetListOfRegionsByPostalCode(PostalCode,City = "") Export
	
	ReturnValueList = New ValueList;
	
	Query = New Query();
	Query.Text = "SELECT DISTINCT
	             |	Poland_AddressClassifier.Region
	             |FROM
	             |	InformationRegister.Poland_AddressClassifier AS Poland_AddressClassifier";
				 
	IsWhere = False;
	WhereText = "";
	
	If NOT IsBlankString(PostalCode) Then
		If IsWhere Then
			WhereText = WhereText + " AND ";
		EndIf;	
		WhereText = WhereText + "Poland_AddressClassifier.PostalCode = &PostalCode";
		IsWhere = True;
	EndIf;	
	If NOT IsBlankString(City) Then
		If IsWhere Then
			WhereText = WhereText + " AND ";
		EndIf;	
		WhereText = WhereText + "Poland_AddressClassifier.City = &City";
		IsWhere = True;
	EndIf;	
	If IsWhere Then
		Query.Text = Query.Text + " WHERE " + WhereText;
	EndIf;
	Query.SetParameter("PostalCode",PostalCode);
	Query.SetParameter("City",City);
	ReturnValueList.LoadValues(Query.Execute().Unload().UnloadColumn("Region"));
	ReturnValueList.SortByValue();
	Return ReturnValueList;
	
EndFunction	

Function GetRegionIfOne(PostalCode,City = "") Export
	
	ValueList = GetListOfRegionsByPostalCode(PostalCode,City);
	If ValueList.Count() = 1 Then
		Return ValueList[0].Value;
	EndIf;
	
EndFunction

Function ChooseRegionByPostalCode(PostalCode,City = "") Export
	
	ValueList = GetListOfRegionsByPostalCode(PostalCode,City);
	Return ValueList.ChooseItem();
	
EndFunction	

Function GetListOfCitiesByPostalCode(PostalCode,Region = "") Export
	
	ReturnValueList = New ValueList;
	
	Query = New Query();
	Query.Text = "SELECT DISTINCT
	             |	Poland_AddressClassifier.City
	             |FROM
	             |	InformationRegister.Poland_AddressClassifier AS Poland_AddressClassifier";
	IsWhere = False;
	WhereText = "";
	
	If NOT IsBlankString(PostalCode) Then
		If IsWhere Then
			WhereText = WhereText + " AND ";
		EndIf;	
		WhereText = WhereText + "Poland_AddressClassifier.PostalCode = &PostalCode";
		IsWhere = True;
	EndIf;	
	If NOT IsBlankString(Region) Then
		If IsWhere Then
			WhereText = WhereText + " AND ";
		EndIf;	
		WhereText = WhereText + "Poland_AddressClassifier.Region = &Region";
		IsWhere = True;
	EndIf;	
	If IsWhere Then
		Query.Text = Query.Text + " WHERE " + WhereText;
	EndIf;
	Query.SetParameter("PostalCode",PostalCode);
	Query.SetParameter("Region",Region);
	ReturnValueList.LoadValues(Query.Execute().Unload().UnloadColumn("City"));
	ReturnValueList.SortByValue();
	Return ReturnValueList;
	
EndFunction	

Function GetCityIfOne(PostalCode,Region = "") Export
	
	ValueList = GetListOfCitiesByPostalCode(PostalCode,Region);
	If ValueList.Count() = 1 Then
		Return ValueList[0].Value;
	EndIf;
	
EndFunction

Function ChooseCityByPostalCode(PostalCode,Region = "") Export
	
	ValueList = GetListOfCitiesByPostalCode(PostalCode,Region);
	Return ValueList.ChooseItem();
	
EndFunction	


Function GetListOfStreetsByPostalCode(PostalCode, Region = "", City = "") Export
	
	ReturnValueList = New ValueList;
	
	Query = New Query();
	Query.Text = "SELECT DISTINCT
	             |	Poland_AddressClassifier.Street
	             |FROM
	             |	InformationRegister.Poland_AddressClassifier AS Poland_AddressClassifier";
	IsWhere = False;
	WhereText = "";
	
	If NOT IsBlankString(PostalCode) Then
		If IsWhere Then
			WhereText = WhereText + " AND ";
		EndIf;	
		WhereText = WhereText + "Poland_AddressClassifier.PostalCode = &PostalCode";
		IsWhere = True;
	EndIf;	
	If NOT IsBlankString(Region) Then
		If IsWhere Then
			WhereText = WhereText + " AND ";
		EndIf;	
		WhereText = WhereText + "Poland_AddressClassifier.Region = &Region";
		IsWhere = True;
	EndIf;	
	If NOT IsBlankString(City) Then
		If IsWhere Then
			WhereText = WhereText + " AND ";
		EndIf;	
		WhereText = WhereText + "Poland_AddressClassifier.City = &City";
		IsWhere = True;
	EndIf;	
	
	If IsWhere Then
		Query.Text = Query.Text + " WHERE " + WhereText;
	EndIf;
	
	Query.SetParameter("PostalCode",PostalCode);
	Query.SetParameter("Region",Region);
	Query.SetParameter("City",City);
	ReturnValueList.LoadValues(Query.Execute().Unload().UnloadColumn("Street"));
	ReturnValueList.SortByValue();
	Return ReturnValueList;
	
EndFunction	

Function GetStreetIfOne(PostalCode, Region = "", City = "") Export
	
	ValueList = GetListOfStreetsByPostalCode(PostalCode,Region,City);
	If ValueList.Count() = 1 Then
		Return ValueList[0].Value;
	EndIf;
	
EndFunction

Function ChooseStreetByPostalCode(PostalCode, Region = "", City = "") Export
	
	ValueList = GetListOfStreetsByPostalCode(PostalCode,Region,City);
	ValueList.SortByPresentation();
	Return ValueList.ChooseItem();
	
EndFunction	

Function GetGminaAndPowiatAsAddressComment(PostalCode, City) Export
	
	Query = New Query();
	Query.Text = "SELECT TOP 1
	             |	Poland_AddressClassifier.Powiat,
	             |	Poland_AddressClassifier.Gmina
	             |FROM
	             |	InformationRegister.Poland_AddressClassifier AS Poland_AddressClassifier
	             |WHERE
	             |	Poland_AddressClassifier.PostalCode = &PostalCode
	             |	AND Poland_AddressClassifier.City = &City";
	Query.SetParameter("City",City);
	Query.SetParameter("PostalCode",PostalCode);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return TrimAll(Selection.Powiat + " " + Selection.Gmina);
	Else
		Return "";
	EndIf;	
	
EndFunction	

Function GetPowiatByPostalCodeAndCity(PostalCode, City) Export
	
	Query = New Query();
	Query.Text = "SELECT TOP 1
	             |	Poland_AddressClassifier.Powiat
	             |FROM
	             |	InformationRegister.Poland_AddressClassifier AS Poland_AddressClassifier
	             |WHERE
	             |	Poland_AddressClassifier.PostalCode = &PostalCode
	             |	AND Poland_AddressClassifier.City = &City";
	Query.SetParameter("City",City);
	Query.SetParameter("PostalCode",PostalCode);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return TrimAll(Selection.Powiat);
	Else
		Return "";
	EndIf;	
	
EndFunction	

Function GetGminaByPostalCodeAndCity(PostalCode, City) Export
	
	Query = New Query();
	Query.Text = "SELECT TOP 1
	             |	Poland_AddressClassifier.Gmina
	             |FROM
	             |	InformationRegister.Poland_AddressClassifier AS Poland_AddressClassifier
	             |WHERE
	             |	Poland_AddressClassifier.PostalCode = &PostalCode
	             |	AND Poland_AddressClassifier.City = &City";
	Query.SetParameter("City",City);
	Query.SetParameter("PostalCode",PostalCode);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return TrimAll(Selection.Gmina);
	Else
		Return "";
	EndIf;	
	
EndFunction	
