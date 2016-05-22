////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Work with undivided users of the infobase

// Called up at setting session parameters.
//
// Parameters:
//  SessionParameterNames - Array, Undefined.
//
Procedure AtSettingSessionParameters(SessionParameterNames) Export
	
	If SessionParameterNames = Undefined Then
		
		If IsSharedInfobaseUser() Then
			RegisterUndividedUserInRegister();
		EndIf;
		
	EndIf;
	
EndProcedure

// Checks if IB user with a set
// identifier is in the list of undivided users.
//
// Parameters:
// InfobaseUserID - UUID - identifier
// of IB user that needs
// to be checked if it belongs to the undivided users.
//
Function UserRegisteredAsUnseparated(Val InfobaseUserID) Export
	
	If Not ValueIsFilled(InfobaseUserID) Then
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SharedUserIDs.InfobaseUserID
	|FROM
	|	InformationRegister.UnseparatedUsers AS SharedUserIDs
	|WHERE
	|	SharedUserIDs.InfobaseUserID = &InfobaseUserID";
	Query.SetParameter("InfobaseUserID", InfobaseUserID);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.UnseparatedUsers");
	LockItem.SetValue("InfobaseUserID", InfobaseUserID);
	LockItem.Mode = DataLockMode.Shared;
	
	BeginTransaction();
	Try
		Block.Lock();
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Not Result.IsEmpty();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Add the handlers of service events (subscriptions)

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	////////////////////////////////////////////////////////////////////////////////
	// Handlers of the Users SSL subsystem events.
	
	ServerHandlers["StandardSubsystems.Users\OnCreateUserAtEntryTime"].Add(
		"UsersServiceSaaSSTL");
	
	ServerHandlers["StandardSubsystems.Users\OnNewIBUserAuthorization"].Add(
		"UsersServiceSaaSSTL");
	
	ServerHandlers["StandardSubsystems.Users\OnBeginIBUserDataProcessing"].Add(
		"UsersServiceSaaSSTL");
	
	ServerHandlers["StandardSubsystems.Users\BeforeWriteIBUser"].Add(
		"UsersServiceSaaSSTL");
		
	////////////////////////////////////////////////////////////////////////////////
	// Handlers of the SaaS SSL subsystem events.
	
	ServerHandlers["StandardSubsystems.SaaS\OnDefinineUserAlias"].Add(
		"UsersServiceSaaSSTL");
	
	////////////////////////////////////////////////////////////////////////////////
	// Handlers of the ExportImportData SSL subsystem events. - export
	// and import of the infobase users
	
	ServerHandlers["ServiceTechnology.DataExportImport\OnImportInfobaseUser"].Add(
		"UsersServiceSaaSSTL");
	
	ServerHandlers["ServiceTechnology.DataExportImport\AfterImportInfobaseUser"].Add(
		"UsersServiceSaaSSTL");
	
	ServerHandlers["ServiceTechnology.DataExportImport\AfterImportInfobaseUsers"].Add(
		"UsersServiceSaaSSTL");
	
	////////////////////////////////////////////////////////////////////////////////
	// Handlers of the ExportImportData SSL subsystem events. - export
	// and import of the infobase data
	
	ServerHandlers["ServiceTechnology.DataExportImport\WhenFillingTypesRequireAnnotationRefsOnImport"].Add(
		"UsersServiceSaaSSTL");
	
	ServerHandlers["ServiceTechnology.DataExportImport\WhenDataImportHandlersRegistration"].Add(
		"UsersServiceSaaSSTL");
	
	ServerHandlers["ServiceTechnology.DataExportImport\WhenDataExportHandlersRegistration"].Add(
		"UsersServiceSaaSSTL");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the Users SSL subsystem events.

// Called during the creation of the Users catalog item when the user signs in interactively.
//
// Parameters:
//  NewUser - CatalogObject.Users,
//  InfobaseUserID - UUID
//
Procedure OnCreateUserAtEntryTime(NewUser) Export
	
	If IsSharedInfobaseUser() Then
		
		NewUser.Service = True;
		NewUser.Description = FullNameOfServiceUser(
			InfobaseUsers.CurrentUser().UUID
		);
		
	EndIf;
	
EndProcedure

// Called on new infobase user authorization.
//
// Parameters:
//  IBUser - InfobaseUser, the current
//  infobase user, StandardProcessing - Boolean, value can be set inside the handler,
//    in this case, the standard authorization processing of new IB user will not be executed.
//
Procedure OnNewIBUserAuthorization(Val CurrentInfobaseUser, StandardProcessing) Export
	
	If CommonUseReUse.DataSeparationEnabled() AND CommonUseReUse.CanUseSeparatedData() Then
		
		// Check data area status
		Manager = InformationRegisters.DataAreas.CreateRecordManager();
		Manager.DataAreaAuxiliaryData = CommonUse.SessionSeparatorValue();
		Manager.Read();
		If Manager.Selected() AND Manager.Status = Enums.DataAreaStatuses.Used Then
			
			If IsSharedInfobaseUser() Then
				
				StandardProcessing = False;
				
				BeginTransaction();
				
				Try
					
					Block = New DataLock();
					LockingCatalog = Block.Add("Catalog.Users");
					Block.Lock();
					
					If Not UsersService.UserByIDExists(CurrentInfobaseUser.UUID) Then
						
						// This is an undivided user, you need to create the item of current field.
						
						UserObject = Catalogs.Users.CreateItem();
						UserObject.Description = FullNameOfServiceUser(CurrentInfobaseUser.UUID);
						UserObject.Service = True;
						UserObject.Write();
						
						UserObject.InfobaseUserID = CurrentInfobaseUser.UUID;
						UserObject.DataExchange.Load = True;
						UserObject.Write();
						
					EndIf;
					
					CommitTransaction();
					
				Except
					
					RollbackTransaction();
					Raise;
					
				EndTry;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Called on the infobase user processing begin.
//
// Parameters:
//  ProcessingParameters - Structure, see comment to
//  the StartIBUserProcessing() procedure IBUserDescription - Structure, see comment to the StartDBUserProcessing() procedure
//
Procedure OnBeginIBUserDataProcessing(ProcessingParameters, IBUserDescription) Export
	
	If ValueIsFilled(ProcessingParameters.OldUser.InfobaseUserID)
	   AND CommonUseReUse.DataSeparationEnabled()
	   AND UserRegisteredAsUnseparated(
	         ProcessingParameters.OldUser.InfobaseUserID) Then
		
		Raise ExceptionTextUnseparatedUsersWriteProhibited();
		
	ElsIf IBUserDescription.Property("UUID")
	        AND ValueIsFilled(IBUserDescription.UUID)
	        AND CommonUseReUse.DataSeparationEnabled()
	        AND UserRegisteredAsUnseparated(
	              IBUserDescription.UUID) Then
		
		// Exclude the overwrite of infobase user during
		// writing of the User catalog items corresponding to undivided users.
		ProcessingParameters.Delete("Action");
		
		If IBUserDescription.Count() > 2
		 OR IBUserDescription.Action = "Delete" Then
			
			Raise ExceptionTextUnseparatedUsersWriteProhibited();
		EndIf;
	EndIf;
	
EndProcedure

// Called before writing of the infobase user
//
// Parameters:
//  InfobaseUserID - UUID
//
Procedure BeforeWriteIBUser(Val ID) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		If UserRegisteredAsUnseparated(ID) Then
			
			Raise ExceptionTextUnseparatedUsersWriteProhibited();
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the SaaS SSL subsystem events.

// Called while defining a user's username to display in the interface.
//
// Parameters:
//  UserID - UUID,
//  Alias - String, username.
//
Procedure OnDefinineUserAlias(UserID, Alias) Export
	
	If UserRegisteredAsUnseparated(UserID) Then
		Alias = FullNameOfServiceUser(UserID);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the ExportImportData SSL subsystem events. - export
// and import of the infobase users

// Fills out an array of types for which it
// is required to use reference abstracts in export files on export.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingTypesRequireAnnotationRefsOnImport(Types) Export
	
	DataProcessors.DataExportImportUserLinksMinimizingInSeparatedData.WhenFillingTypesRequireAnnotationRefsOnImport(
		Types);
	
EndProcedure

// It is called on the registration of the arbitrary handlers of data export.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random export data handlers. Columns:
//    MetadataObject - MetadataObject, when exporting
//      the data of
//    which the registered handler must be called, Handler - GeneralModule, a general module in
//      which random handler of the data export implemented. Set of export procedures
//      that must be implemented in the handler depends on
//      the set values
//    of the following table columns, Version - String - Interface version number of exporting/importing
//      data handlers,
//    supported by handler, BeforeExportType - Boolean, a flag showing
//      that a handler is to be called before exporting
//      all the infobase objects that are associated with the metadata object. If the True value is set - in the general module
//      of a handler, exported procedure
//      BeforeExportType() must be implemented, that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container used in the data export process. See more
//          the review to the application
//        data processor interface DataExportImportContainerManager, Serializer - XDTOSerializer, initiated with
//          support of refs abstracts execution. If a random exporting handler requires
//          additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure BeforeExportType() as the parameter value of Serializer rather
//          than received
//        by using the global context properties SerializerXDTO, MetadataObject - MetadataObject before exporting
//          data of which
//        the handler was called, Cancel - Boolean. If in the BeforeExportType() procedure set this parameter as True - exporting
//          of objects corresponding to the current metadata object will not be executed.
//    BeforeObjectExport - Boolean, a flag showing
//      that it is required to call a handler before exporting a particular object of the infobase. If the
//      True value is set - in the general module of a handler, exported
//      procedure BeforeObjectExport() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container used in the data export process. See more
//          the review to the application
//        data processor interface DataExportImportContainerManager, ExportObjectManager - DataProcessorObject.DataExportImportInfobaseDataExportManager -
//          Manager of the current object export. See more the review to the
//          application data processor interface   
// DataExportImportInfobaseDataExportManager. The parameter is passed
//          only on the call of the handler procedures for which version
//        higher than 1.0.0.1 is specified on registration, Serializer - XDTOSerializer, initiated with
//          support of refs abstracts execution. If a random exporting handler requires
//          additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure BeforeObjectExport() as the parameter value of Serializer rather
//          than received
//        by using the global context properties SerializerXDTO, Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before exporting of which the handler was called.
//          Value that is passed to the BeforeObjectExport() procedure
//          as the Object parameter value can be modified
//          within the BeforeObjectExport() processor, made changes will be shown in the object
//          serialization of export files, but will
//        not be recorded in the Artifacts infobase - Array(XDTOObject) - Set additional information logically
//          connected inextricably with the object but not not being his part artifacts object). Artifacts
//          should formed inside handler PeredVygruzkojOb ekta. 0″ and added
//          to the array passed as parameter values Artifacts. Each artifact must be
//          the XDTOobject for which type, as the base type, abstract
//          XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem. Further
//          artifacts that are formed in the procedure BeforeObjectExport(), will
//          be available in handlers procedures of data import (see review for the procedure WhenDataImportHandlersRegistration().
//        Cancel - Boolean. If you set True
//           for the parameter in procedure BeforeObjectExport() - object export for which the
//           handler was called will not be executed.
//    AfterExportType() - Boolean, a flag showing that a
//      handler is to be called after exporting all objects of the infobase that belongs to that metadata object. If the
//      True value is set - in a general module of the handler, exported
//      procedure AfterExportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container used in the data export process. See more
//          the review to the application
//        data processor interface DataExportImportContainerManager, Serializer - XDTOSerializer, initiated with
//          support of refs abstracts execution. If a random exporting handler requires
//          additional data export - You
//          should use SerializerXDTO that is passed to
//          the procedure AfterExportType() as the parameter value of Serializer rather
//          than received
//        by using the global context properties SerializerXDTO, MetadataObject - MetadataObject, after exporting
//          data of which the handler was called.
//
Procedure WhenDataImportHandlersRegistration(HandlersTable) Export
	
	DataProcessors.DataExportImportUserLinksMinimizingInSeparatedData.WhenDataImportHandlersRegistration(
		HandlersTable);
	
EndProcedure

// It is called on registering the data import arbitrary handlers.
//
// Parameters: HandlersTable - ValueTable, in
//  this procedure it is required to supplement this
//  table of values with information about registered random import data handlers. Columns:
//    MetadataObject - MetadataObject, when importing
//      the data of
//    which the registered handler must be called, Handler - GeneralModule, a general module in
//      which a random handler of the data import is implemented. Set of export procedures
//      that must be implemented in the handler depends on
//      the set values
//    of the following table columns, Version - String - Interface version number of exporting/importing
//      data handlers,
//    supported by handler BeforeMatchRefs - Boolean, a flag showing
//      that a handler is to be called before matching the references (in
//      original and current IB) that belong to the metadata object. If the True value is set - in a general module
//      of the handler, exported procedure
//      BeforeMatchRefs() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more
//          information, see comment to the application interface of data processor DataExportImportContainerManager.
//        MetadataObject - MetadataObject before matching
//          the references of
//        which the handler was called, StandardProcessing - Boolean. If procedure
//          BeforeMatchRefs() install that False parameter value instead of
//          standard mathcing refs (search of objects in the current IB with
//          the same natural key values, that were exported
//          from the IBsource) function MatchRefs() will be
//          called of general module, in
//          the procedure BeforeMatchRefs() which the value parameter StandardDataProcessor  was installed to False.
//          MatchRefs() function parameters:
//            Container - DataProcessorObject.DataExportImportContainerManager - manager
//              of a container that is used in the data import process. See more
//              the review to the application
//            processing interface DataExportImportContainerManager, SourceLinksTable - ValueTable, that contains information
//              about the links exported from the original IB. Columns:
//                SourceRef - AnyReference, an object ref of
//                  the initial IB that is to
//                be matched to a ref of the current IB,
//                  Other columns equal to fields of the
//                  object
//          natural key. The columns are passed to function Handling.ExportImportDataInfobaseDataExportManager.RequireRefMatchingOnImport() when exporting data. Return value of the function is MatchRefs() - ValueTable, columns:
//            SourceRef - AnyReference, object refs, exported from
//            the original IB, Refs - AnyRef mapped with the original reference in current IB.
//        Cancel - Boolean. If you set True for the parameter in procedure BeforeMatchRefs() - matching of
//          the links corresponding to the current metadata object will not be executed.
//    BeforeImportType - Boolean, flag showing that a handler is to be called before importing all data objects that belong to the metadata object. If the True value is set - in a general module of the handler, exported procedure BeforeImportType() must be implemented that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more
//          information, see comment to the application interface of data processor DataExportImportContainerManager.
//        MetadataObject - MetadataObject, before importing
//          all data of
//        which the handler was called, Cancel - Boolean. If you set True for the parameter in procedure BeforeImportType()- importing of all the
//          data objects corresponding to the current metadata object will not be executed.
//    BeforeObjectImport - Boolean flag of need
//      to call handler before importing the data
//      object that belongs to that metadata object. If the True value is set - in the general module
//      of a handler exported procedure
//      must be implemented BeforeObjectImport(), that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more
//          information, see comment to the application interface of data processor DataExportImportContainerManager.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base before importing of which the handler was called.
//          Value that is passed to procedure BeforeObjectImport() as the Object parameter value can be modified within the handler procedure BeforeObjectImport().
//        Artifacts - Array(XDTOObject) - additional data that
//          is logically inextricably associated with the data object, but not being part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be
//          the XDTOobject for which type, as the base type, abstract
//          XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//        Cancel - Boolean. If in the procedure BeforeObjectImport()
//          install this True parameter value - Import of the data object will not be executed.
//    AftertObjectImport - Boolean flag of need
//      to call handler after importing the data
//      object that belongs to that metadata object. If the True value is set - in the general module
//      of a handler exported procedure
//      must be implemented AftertObjectImport(), that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more
//          information, see comment to the application interface of data processor DataExportImportContainerManager.
//        Object - ConstantValueManager.*,
//          CatalogObject.*, DocumentObject.*, BusinessProcessObject.*, TaskObject.*,
//          ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//          ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*,
//          AccumulationRegisterRecordSet.*, AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*, RecalculationRecordSet.* -
//          data object of the info base after importing of which the handler was called.
//        Artifacts - Array(XDTOObject) - additional data that
//          is logically inextricably associated with the data object, but not being part of it. Created in exported procedures BeforeObjectExport() of data export handlers (see a comment to procedure OnDataExportHandlersRegistration(). Each artifact must be
//          the XDTOobject for which type, as the base type, abstract
//          XDTOtype is used {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. It is
//          allowed to use XDTOpackages in addition to the originally supplied content DataExportImport subsystem.
//    AfterImportType - Boolean flag of need
//      to call handler after importing of all data
//      objects that belong to that metadata object. If the True value is set - in the general module
//      of a handler exported procedure
//      must be implemented AfterImportType(), that supports the following parameters:
//        Container - DataProcessorObject.DataExportImportContainerManager - manager
//          of a container that is used in the data import process. For more
//          information, see comment to the application interface of data processor DataExportImportContainerManager.
//        MetadataObject - MetadataObject, after importing
//          all objects of which the handler was called.
//
Procedure WhenDataExportHandlersRegistration(HandlersTable) Export
	
	DataProcessors.DataExportImportUserLinksMinimizingInSeparatedData.WhenDataExportHandlersRegistration(
		HandlersTable);
	
EndProcedure

// Called before importing the infobase user.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. For details,
//    see comment to the application
//  interface of the ExportImportDataContainerManager processing, Serialization - XDTOObject
//    {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfobaseUser, serialization of
//  the infobase user, IBUser - InfobaseUser deserialized
//  from export, Cancel - Boolean, import of the current infobase user will
//    be skipped during setting of this parameter value into the procedure as the False value.
//
Procedure OnImportInfobaseUser(Container, Serialization, IBUser, Cancel) Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		
		IBUser.ShowInList = True;
		// Insert the SystemAdministrator role to the user with the FullRights role.
		If IBUser.Roles.Contains(Metadata.Roles.FullRights) Then
			IBUser.Roles.Add(Metadata.Roles.SystemAdministrator);
		EndIf;
		
		InfobaseUpdateService.SetFlagDisplayDescriptionsForNewUser(IBUser.Name);
		
	EndIf;
	
EndProcedure

// Called after importing the infobase user
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. For details,
//    see comment to the application
//  interface of the ExportImportDataContainerManager processing, Serialization - XDTOObject
//    {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfobaseUser, serialization of
//  the infobase user, IBUser - InfobaseUser deserialized from exporting.
//
Procedure AfterImportInfobaseUser(Container, Serialization, IBUser) Export
	
	If Not Container.AdditionalProperties.Property("UsersMatch") Then
		Container.AdditionalProperties.Insert("UsersMatch", New Map());
	EndIf;
	
	Container.AdditionalProperties.UsersMatch.Insert(Serialization.UUID, IBUser.UUID);
	
EndProcedure

// Called after import of all infobase users.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. For more
//    information, see comment to the application interface of data processor DataExportImportContainerManager.
//
Procedure AfterImportInfobaseUsers(Container) Export
	
	If Container.AdditionalProperties.Property("UsersMatch") Then
		RefreshInfobaseUsersIdentifiers(Container.AdditionalProperties.UsersMatch);
	Else
		RefreshInfobaseUsersIdentifiers(New Map);
	EndIf;
	
	Container.AdditionalProperties.Insert("UsersMatch", Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Update handlers

Procedure RegisterUpdateHandlers(Val Handlers) Export
	
	Handler                  = Handlers.Add();
	Handler.Version           = "1.0.2.10";
	Handler.ExclusiveMode = False;
	Handler.SharedData      = True;
	Handler.Procedure        = "UsersServiceSaaSSTL.FillUnseparatedUsersNames";
	
EndProcedure

Procedure FillUnseparatedUsersNames() Export
	
	QueryText = "SELECT
	               |	UnseparatedUsers.InfobaseUserID,
	               |	UnseparatedUsers.SequenceNumber
	               |FROM
	               |	InformationRegister.UnseparatedUsers AS UnseparatedUsers
	               |WHERE
	               |	UnseparatedUsers.UserName = """"";
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		User = InfobaseUsers.FindByUUID(Selection.InfobaseUserID);
		If User = Undefined Then
			Continue;
		EndIf;
		
		Set = InformationRegisters.UnseparatedUsers.CreateRecordSet();
		Set.Filter.InfobaseUserID.Set(Selection.InfobaseUserID);
		Record = Set.Add();
		Record.InfobaseUserID = Selection.InfobaseUserID;
		Record.SequenceNumber = Selection.SequenceNumber;
		Record.UserName = User.Name;
		Set.Write();
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of the subscriptions to events.

Procedure GetUserFormProcessing(Source, FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing) Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If FormKind = "ObjectForm"
		AND Parameters.Property("Key") AND Not Parameters.Key.IsEmpty() Then
		
		SetPrivilegedMode(True);
		
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	1
		|FROM
		|	InformationRegister.UnseparatedUsers AS UnseparatedUsers
		|		INNER JOIN Catalog.Users AS Users
		|		ON UnseparatedUsers.InfobaseUserID = Users.InfobaseUserID
		|			AND (Users.Ref = &Ref)";
		Query.SetParameter("Ref", Parameters.Key);
		If Not Query.Execute().IsEmpty() Then
			StandardProcessing = False;
			SelectedForm = Metadata.CommonForms.UnsharedUserInfo;
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Work with undivided users of the infobase

// Returns the full name of the user to display in the interfaces.
//
// Parameters:
//  ID - unique identifier of the IB user or CatalogRef.Users.
//
// Returns:
//  String
//
Function FullNameOfServiceUser(Val ID = Undefined) Export
	
	Result = NStr("en = '<Service user %1>'");
	
	If ValueIsFilled(ID) Then
		
		If TypeOf(ID) = Type("CatalogRef.Users") Then
			ID = CommonUse.GetAttributeValue(ID, "InfobaseUserID");
		EndIf;
		
		SequenceNumber = Format(InformationRegisters.UnseparatedUsers.SequenceNumberIBUser(ID), "NFD=0; NG=0");
		Result = StringFunctionsClientServer.PlaceParametersIntoString(Result, SequenceNumber);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Checks if the current IB user is undivided.
//
// Return value: Boolean.
//
Function IsSharedInfobaseUser()
	
	If IsBlankString(InfobaseUsers.CurrentUser().Name) Then
		Return False;
	EndIf;
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	If InfobaseUsers.CurrentUser().DataSeparation.Count() = 0 Then
		
		If CommonUseReUse.CanUseSeparatedData() Then
			
			UserID = InfobaseUsers.CurrentUser().UUID;
			
			If Not UserRegisteredAsUnseparated(UserID) Then
				
				Raise StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en = 'User with the %1 identifier is not registered as undivided!'"),
					String(UserID)
				);
				
			EndIf;
			
		EndIf;
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

// During work in the service model it enlists the
// current user to the list of undivided if it has not set the use of separators.
//
Procedure RegisterUndividedUserInRegister() Export
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.UnseparatedUsers");
		Block.Lock();
		
		RecordManager = InformationRegisters.UnseparatedUsers.CreateRecordManager();
		RecordManager.InfobaseUserID = InfobaseUsers.CurrentUser().UUID;
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			RecordManager.InfobaseUserID = InfobaseUsers.CurrentUser().UUID;
			RecordManager.SequenceNumber = InformationRegisters.UnseparatedUsers.MaximalSerialNumber() + 1;
			RecordManager.UserName = InfobaseUsers.CurrentUser().Name;
			RecordManager.Write();
		ElsIf RecordManager.UserName <> InfobaseUsers.CurrentUser().Name Then
			RecordManager.UserName = InfobaseUsers.CurrentUser().Name;
			RecordManager.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function ExceptionTextUnseparatedUsersWriteProhibited()
	
	Return NStr("en = 'Write undivided
                  |users during the use of separators is denied.'");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Integration with the Users SSL subsystem

// Refreshes the IB users identifiers in the users catalog, clears the ServiceUserIdentifier field
//
// Parameters:
//  UsersTable - Map - Key: source identifier of
//                         the IB user, Value - current identifier of the IB user
//
Procedure RefreshInfobaseUsersIdentifiers(Val IDMapping)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.InfobaseUserID AS InfobaseUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.InfobaseUserID <> &EmptyID";
	Query.SetParameter("EmptyID", New UUID("00000000-0000-0000-0000-000000000000"));
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		UserObject = Selection.Ref.GetObject();
		UserObject.DataExchange.Load = True;
		UserObject.ServiceUserID = Undefined;
		UserObject.InfobaseUserID 
			= IDMapping[Selection.InfobaseUserID];
		UserObject.Write();
	EndDo;
	
EndProcedure
