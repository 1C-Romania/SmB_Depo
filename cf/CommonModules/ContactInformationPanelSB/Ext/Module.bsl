
#Region FormEvents

Procedure OnCreateAtServer(Form, NameGroupForPlacement = "") Export
	
	CheckCreatePanelAttributes(Form, NameGroupForPlacement);
	SetConditionalAppearance(Form);
	
	If Form.ContactInformationPanelData.Count() = 0 Then
		AddMessageAboutMissingData(Form.ContactInformationPanelData);
	EndIf;
	
EndProcedure

#EndRegion

#Region Interface

Procedure RefreshPanelData(Form, Counterparty) Export
	
	Form.ContactInformationPanelData.Clear();
	
	If Counterparty = Undefined Тогда
		AddMessageAboutMissingData(Form.ContactInformationPanelData);
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ContactInformation.*
		|FROM
		|	Catalog.Counterparties.ContactInformation КАК ContactInformation
		|WHERE
		|	ContactInformation.Ref = &Counterparty";
	
	Query.SetParameter("Counterparty", Counterparty);
	DataCI = Query.Execute().Select();
	
	While DataCI.Next() Do
		NewRow = Form.ContactInformationPanelData.Add();
		Comment = ContactInformationManagement.ContactInformationComment(DataCI.FieldValues);
		NewRow.Representation	= String(DataCI.Kind) + ": " + DataCI.Presentation + ?(IsBlankString(Comment), "", ", " + Comment);
		NewRow.IconIndex		= IconIndexByType(DataCI.Type);
		NewRow.TypeShowingData	= "ValueCI";
		NewRow.OwnerCI			= Counterparty;
		NewRow.PresentationCI	= DataCI.Presentation;
	EndDo;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	OrderTypesCI.Type,
		|	OrderTypesCI.Order
		|INTO ttOrderTypesCI
		|FROM
		|	&OrderTypesCI AS OrderTypesCI
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactPersons.Ref AS ContactPerson,
		|	ContactPersons.Description AS Description,
		|	ContactPersons.Position AS Position,
		|	CASE
		|		WHEN ContactPersons.Ref = &MainContactPerson
		|			THEN 0
		|		ELSE 1
		|	END AS ContactsOrder
		|INTO ttContacts
		|FROM
		|	Catalog.ContactPersons AS ContactPersons
		|WHERE
		|	ContactPersons.DeletionMark = FALSE
		|	AND ContactPersons.Invalid = FALSE
		|	AND ContactPersons.Owner = &Owner
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ttContacts.ContactPerson,
		|	ttContacts.Description AS Description,
		|	ttContacts.Position
		|FROM
		|	ttContacts AS ttContacts
		|
		|ORDER BY
		|	ttContacts.ContactsOrder,
		|	Description
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactPersonsContactInformation.Ref AS ContactPerson,
		|	ContactPersonsContactInformation.Type AS Type,
		|	ContactPersonsContactInformation.Kind AS Kind,
		|	ContactPersonsContactInformation.Presentation AS Presentation,
		|	ContactPersonsContactInformation.FieldValues AS FieldValues,
		|	PRESENTATION(ContactPersonsContactInformation.Kind) AS KindPresentationCI
		|FROM
		|	Catalog.ContactPersons.ContactInformation AS ContactPersonsContactInformation
		|		LEFT JOIN ttOrderTypesCI AS ttOrderTypesCI
		|		ON ContactPersonsContactInformation.Type = ttOrderTypesCI.Type
		|WHERE
		|	ContactPersonsContactInformation.Ref IN
		|			(SELECT
		|				ttContacts.ContactPerson
		|			FROM
		|				ttContacts)
		|
		|ORDER BY
		|	ttOrderTypesCI.Order,
		|	ContactPersonsContactInformation.Kind.Description";
	
	Query.SetParameter("Owner", Counterparty);
	Query.SetParameter("MainContactPerson", CommonUse.ObjectAttributeValue(Counterparty, "ContactPerson"));
	Query.SetParameter("OrderTypesCI", ContactInformationSB.OrderTypesCI());
	
	ResultsArray = Query.ExecuteBatch();
	
	SelectionContacts = ResultsArray[2].Select();
	SelectionContactInformation = ResultsArray[3].Select();
	FilterCI = New Structure("ContactPerson");
	
	While SelectionContacts.Next() Do
		
		NewRow = Form.ContactInformationPanelData.Add();
		NewRow.Representation	= String(SelectionContacts.ContactPerson);
		NewRow.IconIndex		= -1;
		NewRow.TypeShowingData	= "ContactPerson";
		NewRow.OwnerCI			= SelectionContacts.ContactPerson;
		
		SelectionContactInformation.Reset();
		FilterCI.ContactPerson = SelectionContacts.ContactPerson;
		
		While SelectionContactInformation.FindNext(FilterCI) Do
			
			NewRow = Form.ContactInformationPanelData.Add();
			Comment = ContactInformationManagement.ContactInformationComment(SelectionContactInformation.FieldValues);
			NewRow.Representation	= String(SelectionContactInformation.Kind) + ": " +SelectionContactInformation.Presentation + ?(IsBlankString(Comment), "", ", " + Comment);
			NewRow.IconIndex		= IconIndexByType(SelectionContactInformation.Type);
			NewRow.TypeShowingData	= "ValueCI";
			NewRow.OwnerCI			= SelectionContacts.ContactPerson;
			NewRow.PresentationCI	= SelectionContactInformation.Presentation;
			
		EndDo;
		
	EndDo;
	
	If Form.ContactInformationPanelData.Count() = 0 Then
		AddMessageAboutMissingData(Form.ContactInformationPanelData);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure CheckCreatePanelAttributes(Form, NameGroupForPlacement)
	
	FormAttributesList = Form.GetAttributes();
	
	FirstLaunch = True;
	For Each Attribute In FormAttributesList Do
		If Attribute.Name = "ContactInformationPanelData" Then
			FirstLaunch = False;
			Break;
		EndIf;
	EndDo;
	
	If Not FirstLaunch Then
		Return;
	EndIf;
	
	AddingAttributes = New Array;
	
	// Create value table
	TableName = "ContactInformationPanelData";
	AddingAttributes.Add(New FormAttribute(TableName, New TypeDescription("ValueTable")));
	AddingAttributes.Add(New FormAttribute("Representation", New TypeDescription("String", , New StringQualifiers(150)), TableName));
	AddingAttributes.Add(New FormAttribute("IconIndex", New TypeDescription("Number"), TableName));
	AddingAttributes.Add(New FormAttribute("TypeShowingData", New TypeDescription("String", , New StringQualifiers(20)), TableName));
	AddingAttributes.Add(New FormAttribute("OwnerCI", New TypeDescription("CatalogRef.Counterparties, CatalogRef.ContactPersons"), TableName));
	AddingAttributes.Add(New FormAttribute("PresentationCI", New TypeDescription("String", , New StringQualifiers(500)), TableName));
	
	Form.ChangeAttributes(AddingAttributes);
	
	// Create items
	FormTable = Form.Items.Add(TableName, Type("FormTable"), Form.Items[NameGroupForPlacement]);
	FormTable.DataPath				= TableName;
	FormTable.CommandBarLocation	= FormItemCommandBarLabelLocation.None;
	FormTable.ChangeRowSet			= False;
	FormTable.ChangeRowOrder		= False;
	FormTable.RowSelectionMode		= TableRowSelectionMode.Row;
	FormTable.Header				= False;
	FormTable.AutoInsertNewRow		= False;
	FormTable.EnableStartDrag		= False;
	FormTable.EnableDrag			= False;
	FormTable.HorizontalScrollBar	= ScrollBarUse.DontUse;
	FormTable.VerticalScrollBar		= ScrollBarUse.DontUse;
	FormTable.HorizontalLines		= False;
	FormTable.VerticalLines			= False;
	FormTable.BorderColor			= StyleColors.FormBackColor;
	FormTable.Width					= 25;
	FormTable.Height				= 10;
	FormTable.HorizontalStretch		= False;
	FormTable.SetAction("Selection",		"Attachable_ContactInformationPanelDataSelection");
	FormTable.SetAction("OnActivateRow",	"Attachable_ContactInformationPanelDataOnActivateRow");
	
	Representation = Form.Items.Add(TableName + "Representation", Type("FormField"), FormTable);
	Representation.DataPath			= TableName + ".Representation";
	Representation.Type				= FormFieldType.LabelField;
	Representation.EditMode			= ColumnEditMode.Enter;
	Representation.AutoCellHeight	= True;
	Representation.Width			= 23;
	
	Icon = Form.Items.Add(TableName + "Icon", Type("FormField"), FormTable);
	Icon.DataPath			= TableName + ".IconIndex";
	Icon.Type				= FormFieldType.PictureField;
	Icon.ValuesPicture		= PictureLib.ContactInformationKinds;
	Icon.AutoCellHeight		= True;
	Icon.CellHyperlink		= True;
	Icon.Border				= New Border(ControlBorderType.WithoutBorder, -1);
	Icon.Width				= 1;
	Icon.HorizontalStretch	= False;
	Icon.VerticalStretch	= False;
	
	AddContextMenuCommand(Form,
		"ContextMenuPanelMapGoogle",
		PictureLib.GoogleMaps,
		NStr("ru = 'Адрес на Google Maps'; en = 'Address on Google Maps'"),
		NStr("ru = 'Показывает адрес на карте Google Maps'; en = 'Show address on Google Maps'"),
		FormTable
	);
	
EndProcedure

Function IconIndexByType(TypeCI)
	
	If TypeCI = Enums.ContactInformationTypes.Address Then
		IconIndex = 12;
	ElsIf TypeCI = Enums.ContactInformationTypes.EmailAddress Then
		IconIndex = 8;
	ElsIf TypeCI = Enums.ContactInformationTypes.WebPage Then
		IconIndex = 9;
	ElsIf TypeCI = Enums.ContactInformationTypes.Skype Then
		IconIndex = 20;
	ElsIf TypeCI = Enums.ContactInformationTypes.Other Then
		IconIndex = 11;
	ElsIf TypeCI = Enums.ContactInformationTypes.Phone Then
		IconIndex = 7;
	ElsIf TypeCI = Enums.ContactInformationTypes.Fax Then
		IconIndex = 10;
	Else
		IconIndex = 0;
	EndIf;
	
	Return IconIndex;
	
EndFunction

Procedure SetConditionalAppearance(Form)
	
	// 1. 1. The value of the contact information - the usual style, contacts - select
	NewConditionalAppearance = Form.ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("TextColor");
	Appearance.Value	= StyleColors.TextColorRightFilterPanel;
	Appearance.Use		= True;
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("Font");
	Appearance.Value	= StyleFonts.FontRightFilterPanel;
	Appearance.Use		= True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType	= DataCompositionComparisonType.Equal;
	Filter.Use				= True;
	Filter.LeftValue		= New DataCompositionField("ContactInformationPanelData.TypeShowingData");
	Filter.RightValue		= "ContactPerson";
	
	FieldAppearance = NewConditionalAppearance.Fields.Items.Add();
	FieldAppearance.Field	= New DataCompositionField("ContactInformationPanelDataRepresentation");
	FieldAppearance.Use		= True;
	
EndProcedure

Procedure AddMessageAboutMissingData(ContactInformationPanelData)
	
	NewRow = ContactInformationPanelData.Add();
	NewRow.Representation	= NStr("ru='<Нет контактных данных>'; en = '<No contact data>'");
	NewRow.IconIndex		= -1;
	NewRow.TypeShowingData	= "NoData";
	NewRow.OwnerCI			= Undefined;
	
EndProcedure

Procedure AddContextMenuCommand(Form, CommandName, Picture, Title, ToolTip, FieldOwner)
	
	If Form.Commands.Find(CommandName) = Undefined Then
		Command = Form.Commands.Add(CommandName);
		Command.Picture = Picture;
		Command.Title = Title;
		Command.ToolTip = ToolTip;
		Command.Action = "Attachable_ContactInformationPanelDataExecuteCommand";
	EndIf;
	
	Button = Form.Items.Add(CommandName, Type("FormButton"), FieldOwner.ContextMenu);
	Button.CommandName = CommandName;
	
EndProcedure

#EndRegion
