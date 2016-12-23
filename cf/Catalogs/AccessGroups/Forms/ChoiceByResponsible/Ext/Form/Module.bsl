
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Selected",                 Parameters.Selected);
	Query.SetParameter("GroupUser",         Parameters.GroupUser);
	Query.SetParameter("Responsible",             Users.AuthorizedUser());
	Query.SetParameter("ResponsibleWithFullRights", Users.InfobaseUserWithFullAccess());
	
	SetPrivilegedMode(True);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref,
	|	AccessGroups.Description,
	|	AccessGroups.IsFolder,
	|	CASE
	|		WHEN AccessGroups.IsFolder
	|				AND Not AccessGroups.DeletionMark
	|			THEN 0
	|		WHEN AccessGroups.IsFolder
	|				AND AccessGroups.DeletionMark
	|			THEN 1
	|		WHEN Not AccessGroups.IsFolder
	|				AND Not AccessGroups.DeletionMark
	|			THEN 3
	|		ELSE 4
	|	END AS PictureNumber,
	|	FALSE AS Check
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	CASE
	|			WHEN AccessGroups.IsFolder
	|				THEN TRUE
	|			WHEN AccessGroups.Ref IN (&Selected)
	|				THEN FALSE
	|			WHEN AccessGroups.DeletionMark
	|				THEN FALSE
	|			WHEN AccessGroups.Profile.DeletionMark
	|				THEN FALSE
	|			WHEN AccessGroups.Ref = VALUE(Catalog.AccessGroups.Administrators)
	|				THEN &ResponsibleWithFullRights
	|						AND VALUETYPE(&GroupUser) = Type(Catalog.Users)
	|			WHEN &ResponsibleWithFullRights = FALSE
	|					AND AccessGroups.Responsible <> &Responsible
	|				THEN FALSE
	|			ELSE CASE
	|						WHEN AccessGroups.User = UNDEFINED
	|							THEN TRUE
	|						WHEN AccessGroups.User = VALUE(Catalog.Users.EmptyRef)
	|							THEN TRUE
	|						WHEN AccessGroups.User = VALUE(Catalog.ExternalUsers.EmptyRef)
	|							THEN TRUE
	|						ELSE AccessGroups.User = &GroupUser
	|					END
	|					AND CASE
	|						WHEN AccessGroups.UsersType = UNDEFINED
	|							THEN TRUE
	|						WHEN VALUETYPE(AccessGroups.UsersType) = Type(Catalog.Users)
	|							THEN CASE
	|									WHEN VALUETYPE(&GroupUser) = Type(Catalog.Users)
	|											OR VALUETYPE(&GroupUser) = Type(Catalog.UsersGroups)
	|										THEN TRUE
	|									ELSE FALSE
	|								END
	|						WHEN VALUETYPE(&GroupUser) = Type(Catalog.ExternalUsers)
	|							THEN TRUE In
	|									(SELECT TOP 1
	|										TRUE
	|									FROM
	|										Catalog.ExternalUsers AS ExternalUsers
	|									WHERE
	|										ExternalUsers.Ref = &GroupUser
	|										AND VALUETYPE(ExternalUsers.AuthorizationObject) = VALUETYPE(AccessGroups.UsersType))
	|						WHEN VALUETYPE(&GroupUser) = Type(Catalog.ExternalUsersGroups)
	|							THEN TRUE In
	|									(SELECT TOP 1
	|										TRUE
	|									FROM
	|										Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|									WHERE
	|										ExternalUsersGroups.Ref = &GroupUser
	|										AND VALUETYPE(ExternalUsersGroups.TypeOfAuthorizationObjects) = VALUETYPE(AccessGroups.UsersType))
	|						ELSE FALSE
	|					END
	|		END
	|
	|ORDER BY
	|	AccessGroups.Ref HIERARCHY";
	
	NewTree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	Folders = NewTree.Rows.FindRows(New Structure("IsFolder", True), True);
	
	DeleteFolders = New Map;
	NoFolders = True;
	
	For Each Folder IN Folders Do
		If Folder.Parent = Undefined
		   AND Folder.Rows.Count() = 0
		 OR Folder.Rows.FindRows(New Structure("IsFolder", False), True).Count() = 0 Then
			
			DeleteFolders.Insert(
				?(Folder.Parent = Undefined, NewTree.Rows, Folder.Parent.Rows),
				Folder);
		Else
			NoFolders = False;
		EndIf;
	EndDo;
	
	For Each DeleteFolder IN DeleteFolders Do
		If DeleteFolder.Key.IndexOf(DeleteFolder.Value) > -1 Then
			DeleteFolder.Key.Delete(DeleteFolder.Value);
		EndIf;
	EndDo;
	
	NewTree.Rows.Sort("IsFolder Decr, Description Asc", True);
	ValueToFormAttribute(NewTree, "AccessGroups");
	
	If NoFolders Then
		Items.AccessGroups.Representation = TableRepresentation.List;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersAccessGroups

&AtClient
Procedure AccessGroupsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OnChoose();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	
	OnChoose();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OnChoose()
	
	CurrentData = Items.AccessGroups.CurrentData;
	
	If CurrentData <> Undefined Then
		If CurrentData.IsFolder Then
			
			If Items.AccessGroups.Expanded(Items.AccessGroups.CurrentRow) Then
				Items.AccessGroups.Collapse(Items.AccessGroups.CurrentRow);
			Else
				Items.AccessGroups.Expand(Items.AccessGroups.CurrentRow);
			EndIf;
		Else
			NotifyChoice(CurrentData.Ref);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion














