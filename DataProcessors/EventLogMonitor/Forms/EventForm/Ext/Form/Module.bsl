
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Date                        = Parameters.Date;
	UserName             = Parameters.UserName;
	ApplicationPresentation     = Parameters.ApplicationPresentation;
	Computer                   = Parameters.Computer;
	Event                     = Parameters.Event;
	EventPresentation        = Parameters.EventPresentation;
	Comment                 = Parameters.Comment;
	MetadataPresentation     = Parameters.MetadataPresentation;
	Data                      = Parameters.Data;
	DataPresentation         = Parameters.DataPresentation;
	TransactionID                  = Parameters.TransactionID;
	TransactionStatus            = Parameters.TransactionStatus;
	Session                       = Parameters.Session;
	ServerName               = Parameters.ServerName;
	Port              = Parameters.Port;
	SyncPort       = Parameters.SyncPort;
	
	If Parameters.Property("SessionDataSeparation") Then
		SessionDataSeparation = Parameters.SessionDataSeparation;
	EndIf;
	
	// Opening button is enabled for the metadata list.
	If TypeOf(MetadataPresentation) = Type("ValueList") Then
		Items.MetadataPresentation.OpenButton = True;
		Items.AccessMetadataPresentation.OpenButton = True;
		Items.AccessRightRejectionMetadataPresentation.OpenButton = True;
		Items.AccessActionDeniedMetadataPresentation.OpenButton = True;
	EndIf;
	
	// Process special events data.
	Items.AccessData.Visible = False;
	Items.AccessRightDeniedData.Visible = False;
	Items.AccessActionDeniedData.Visible = False;
	Items.AuthenticationData.Visible = False;
	Items.InfobaseUserData.Visible = False;
	Items.SimpleData.Visible = False;
	Items.DataPresentations.PagesRepresentation = FormPagesRepresentation.None;
	
	If Event = "_$Access$_.Access" Then
		Items.DataPresentations.CurrentPage = Items.AccessData;
		Items.AccessData.Visible = True;
		EventData = GetFromTempStorage(Parameters.DataAddress);
		If EventData <> Undefined Then
			CreateFormTable("AccessDataTable", "DataTable", EventData.Data);
		EndIf;
		Items.Comment.VerticalStretch = False;
		Items.Comment.Height = 1;
		
	ElsIf Event = "_$Access$_.AccessDenied" Then
		EventData = GetFromTempStorage(Parameters.DataAddress);
		
		If EventData <> Undefined Then
			If EventData.Property("Right") Then
				Items.DataPresentations.CurrentPage = Items.AccessRightDeniedData;
				Items.AccessRightDeniedData.Visible = True;
				AccessRightDenied = EventData.Right;
			Else
				Items.DataPresentations.CurrentPage = Items.AccessActionDeniedData;
				Items.AccessActionDeniedData.Visible = True;
				AccessActionDenied = EventData.Action;
				CreateFormTable("AccessActionDeniedDataTable", "DataTable", EventData.Data);
				Items.Comment.VerticalStretch = False;
				Items.Comment.Height = 1;
			EndIf;
		EndIf;
		
	ElsIf Event = "_$Session$_.Authentication"
		  OR Event = "_$Session$_.AuthenticationError" Then
		EventData = GetFromTempStorage(Parameters.DataAddress);
		Items.DataPresentations.CurrentPage = Items.AuthenticationData;
		Items.AuthenticationData.Visible = True;
		If EventData <> Undefined Then
			EventData.Property("Name",                   AuthenticationUserName);
			EventData.Property("OSUser",        AuthenticationOSUser);
			EventData.Property("CurrentOSUser", AuthenticationCurrentOSUser);
		EndIf;
		
	ElsIf Event = "_$User$_.Delete"
		  OR Event = "_$User$_.New"
		  OR Event = "_$User$_.Update" Then
		EventData = GetFromTempStorage(Parameters.DataAddress);
		Items.DataPresentations.CurrentPage = Items.InfobaseUserData;
		Items.InfobaseUserData.Visible = True;
		InfobaseUserProperties = New ValueTable;
		InfobaseUserProperties.Columns.Add("Name");
		InfobaseUserProperties.Columns.Add("Value");
		RoleArray = Undefined;
		If EventData <> Undefined Then
			For Each KeyAndValue IN EventData Do
				If KeyAndValue.Key = "Roles" Then
					RoleArray = KeyAndValue.Value;
					Continue;
				EndIf;
				NewRow = InfobaseUserProperties.Add();
				NewRow.Name      = KeyAndValue.Key;
				NewRow.Value = KeyAndValue.Value;
			EndDo;
		EndIf;
		CreateFormTable("InfobaseUserPropertyTable", "DataTable", InfobaseUserProperties);
		If RoleArray <> Undefined Then
			IBUserRoles = New ValueTable;
			IBUserRoles.Columns.Add("Role",, NStr("en = 'Role'"));
			For Each CurrentRole IN RoleArray Do
				IBUserRoles.Add().Role = CurrentRole;
			EndDo;
			CreateFormTable("InfobaseUserRoleTable", "Roles", IBUserRoles);
		EndIf;
		Items.Comment.VerticalStretch = False;
		Items.Comment.Height = 1;
		
	Else
		Items.DataPresentations.CurrentPage = Items.SimpleData;
		Items.SimpleData.Visible = True;
	EndIf;
	
	Items.SessionDataSeparation.Visible = Not CommonUseReUse.CanUseSeparatedData();
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject, "DataGroup, EventGroup, ConnectionGroup, TransactionGroup");
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure MetadataPresentationOpening(Item, StandardProcessing)
	
	ShowValue(, MetadataPresentation);
	
EndProcedure

&AtClient
Procedure SessionDataSeparationOpening(Item, StandardProcessing)
	
	ShowValue(, SessionDataSeparation);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersAccessActionDenialDataTable

&AtClient
Procedure DataTableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(, Item.CurrentData[Mid(Field.Name, StrLen(Item.Name)+1)]);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure CreateFormTable(Val FormTableFieldName, Val AttributeNameFormDataCollection, Val ValueTable)
	
	If TypeOf(ValueTable) <> Type("ValueTable") Then
		ValueTable = New ValueTable;
		ValueTable.Columns.Add("Undefined", , " ");
	EndIf;
	
	// Add attributes to the form table.
	AttributesToAdd = New Array;
	For Each Column IN ValueTable.Columns Do
		AttributesToAdd.Add(New FormAttribute(Column.Name, Column.ValueType, AttributeNameFormDataCollection, Column.Title));
	EndDo;
	ChangeAttributes(AttributesToAdd);
	
	// Add items form
	For Each Column IN ValueTable.Columns Do
		AttributeItem = Items.Add(FormTableFieldName + Column.Name, Type("FormField"), Items[FormTableFieldName]);
		AttributeItem.DataPath = AttributeNameFormDataCollection + "." + Column.Name;
	EndDo;
	
	ValueToFormAttribute(ValueTable, AttributeNameFormDataCollection);
	
EndProcedure

#EndRegion



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
