#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Object application interface is realized through AdditionalProperties:
//
// IBUserDescription - Structure with properties:
//   Action - String - "Write" or "Delete".
//      1. If Action = "Delete" other properties aren't required. Deletion
//      will be considered successful and
//      in that case when IBUser isn't found by attribute value InfobaseUserID.
//      2. If Action = "Write", then the IB user
//      will be created or updated according to the specified properties.
//
//   CanLogOnToApplication - Undefined - calculate automatically:
//                            if the entrance to the application is
//                            forbidden, then remains is forbidden, else
//                            remains is allowed, except a case when all authentication kinds are set in False.
//                          - Boolean - if True, then set authentication
//                            as it is specified or saved in the same name attribute values;
//                            if False, then delete all authentication kinds at IB user.
//                            Property isn't specified - direct installation of
//                            the saving and operating authentication kinds (for return compatibility support).
//
//   StandardAuthentication, OSAuthentication, OpenIDAuthentication - set
//      saving authentication kind values and in dependence on property usage.
//      EnterToProgramIsAllowed, install current authentication kind values.
// 
//   Other properties.
//      The content of other properties is specified similarly to the parameter property content.
//      UpdatedProperties
//      for procedure Users.WriteIBUser() in addition to property FullName - it is set according to Description.
//
//      For mapping an existing free IB user with a
//      user in directory with which another existing IB user is not mapped, it is necessary to insert property.
//      UUID If you specify the ID
//      of IB user, which is mapped with current user, nothing is changed.
//
//   When action execution "Write" and "Delete" object attribute.
//   InfobaseUserID is updated automatically, it shouldn't be changed.
//
//   After action execution the following properties are inserted (updated) in structure:
//   - ActionResult - String containing one of values:
//       "InfobaseUserAdded", "InfobaseUserChanged", "InfobaseUserDeleted",
//       "MatchToNonExistentIBUserCleared", "DeletionDoesnotNeededDBUser".
//   - UUID - UUID of IB user.

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// SERVICE VARIABLES

Var DBUserProcessingParameters; // Parameters that are filled out when processing the IB user.
                                        // It is used in event handler OnWrite.

Var IsNew; // Shows that a new object was written.
                // It is used in event handler OnWrite.

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
	UsersService.BeginOfDBUserProcessing(ThisObject, DBUserProcessingParameters);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("NewUserGroup")
		AND ValueIsFilled(AdditionalProperties.NewUserGroup) Then
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.UsersGroups");
		LockItem.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		GroupObject = AdditionalProperties.NewUserGroup.GetObject();
		GroupObject.Content.Add().User = Ref;
		GroupObject.Write();
	EndIf;
	
	// Update automatic group content "All users".
	ParticipantsOfChange = New Map;
	ChangedGroups   = New Map;
	
	UsersService.UpdateUsersGroupsContents(
		Catalogs.UsersGroups.AllUsers, Ref, ParticipantsOfChange, ChangedGroups);
	
	UsersService.RefreshUsabilityRateOfUsersGroups(
		Ref, ParticipantsOfChange, ChangedGroups);
	
	UsersService.EndOfIBUserProcessing(
		ThisObject, DBUserProcessingParameters);
	
	UsersService.AfterUserGroupStavesUpdating(
		ParticipantsOfChange, ChangedGroups);
	
	UsersService.AfterUserOrGroupChangeAdding(Ref, IsNew);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	GeneralActionsBeforeDeletionInNormalModeAndOnDataExchange();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	AdditionalProperties.Insert("CopyingValue", CopiedObject.Ref);
	
	InfobaseUserID = Undefined;
	ServiceUserID = Undefined;
	Prepared = False;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Only for internal use.
Procedure GeneralActionsBeforeDeletionInNormalModeAndOnDataExchange() Export
	
	// It is required to delete the IB user, else it will get
	// to the error list in the form of IBUsers, besides the input by this IB user will lead to an error.
	
	IBUserDescription = New Structure;
	IBUserDescription.Insert("Action", "Delete");
	AdditionalProperties.Insert("IBUserDescription", IBUserDescription);
	
	UsersService.BeginOfDBUserProcessing(ThisObject, DBUserProcessingParameters, True);
	UsersService.EndOfIBUserProcessing(ThisObject, DBUserProcessingParameters);
	
EndProcedure

#EndRegion

#EndIf
