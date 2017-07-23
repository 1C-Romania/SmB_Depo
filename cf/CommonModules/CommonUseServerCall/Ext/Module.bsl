////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions for work with data in base.

// Checks if there are references to objects in the data base.
//
// Parameters:
//  Refs       - AnyRef
//               - Values array of the AnyRef type.
//
//  SearchInServiceObjects - Boolean - initial value
//                 is False when True is set, then
//                 exception of the refs search specified during disassembling of the configuration will not be taken into account.
//
// Returns:
//  Boolean.
//
Function ThereAreRefsToObject(Val RefOrRefArray, Val SearchInServiceObjects = False) Export
	
	Return CommonUse.ThereAreRefsToObject(RefOrRefArray, SearchInServiceObjects);
	
EndFunction

// Checks if the documents are posted.
//
// Parameters:
//  Documents - Array - documents posting of which is required to be checked.
//
// Returns:
//  Array - unposted documents from the Documents array.
//
Function CheckThatDocumentsArePosted(Val Documents) Export
	
	Return CommonUse.CheckThatDocumentsArePosted(Documents);
	
EndFunction

// Attempts to post documents.
//
// Parameters:
// Documents                - Array - documents required to be posted.
//
// Returns:
// Array - array of structures with fields:
// 								Refs         - document that failed to be posted;
// 								ErrorDescription - text of error on posting description.
//
Function PostDocuments(Documents) Export
	
	Return CommonUse.PostDocuments(Documents);
	
EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions for work in the data separation mode.

// Sets the session separation.
//
// Parameters:
// Use - Boolean - Use the DataArea separator in the session.
// DataArea - Number - Value of the DataArea separator.
//
Procedure SetSessionSeparation(Val Use, Val DataArea = Undefined) Export
	
	CommonUse.SetSessionSeparation(Use, DataArea);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Saving, reading and deleting settings from storage.

// Saves the setting in common settings storage.
// 
// Parameters:
//   Correspond to
// CommonSettingsStorageSave.Save method, for more details - see StorageSave procedure parameters().
// 
Procedure CommonSettingsStorageSave(ObjectKey, SettingsKey = "", Value, SettingsDescription = Undefined,
	UserName = Undefined, NeedToUpdateReusedValues = False) Export
	
	CommonUse.CommonSettingsStorageSave(
		ObjectKey,
		SettingsKey,
		Value,
		SettingsDescription,
		UserName,
		NeedToUpdateReusedValues);
		
EndProcedure

// Imports the setting from common settings storage.
//
// Parameters:
//   Correspond
//   to CommonSettingsStorage.Import method, details - see StorageImport function parameters().
//
Function CommonSettingsStorageImport(ObjectKey, SettingsKey = "", DefaultValue = Undefined, 
	SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return CommonUse.CommonSettingsStorageImport(
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDescription,
		UserName);
		
EndFunction

// Deletes the setting from the common settings storage.
//
// Parameters:
//   Correspond
//   to the CommonSettingsStorage.Delete method, details - see parameters of the DeleteStorage() function.
//
Procedure CommonSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	CommonUse.CommonSettingsStorageDelete(ObjectKey, SettingsKey, UserName);
	
EndProcedure

// Saves an array of the StructuresArray custom settings. 
// Can be applied if there are calls from client.
// 
// Parameters:
//    StructuresArray - Array - array of structures with the Object, Setting, Value fields.
//    NeedToUpdateReusedValues - Boolean - it is required to update used values again.
//
Procedure CommonSettingsStorageSaveArray(StructuresArray, NeedToUpdateReusedValues = False) Export
	
	CommonUse.CommonSettingsStorageSaveArray(StructuresArray, NeedToUpdateReusedValues);
	
EndProcedure

// Saves an array of the StructuresArray custom
//   settings and updates used values again. Can be applied if there are calls from client.
// 
// Parameters:
//    StructuresArray - Array - array of structures with the Object, Setting, Value fields.
//
Procedure CommonSettingsStorageSaveArrayAndUpdateReUseValues(StructuresArray) Export
	
	CommonUse.CommonSettingsStorageSaveArrayAndUpdateReUseValues(StructuresArray);
	
EndProcedure

// Saves a setting to the storage of the common settings
// and updates used values again.
// 
// Parameters:
//   Correspond to
// CommonSettingsStorageSave.Save method, for more details - see StorageSave procedure parameters().
//
Procedure CommonSettingsStorageSaveAndRefreshReusableValues(ObjectKey, SettingsKey, Value) Export
	
	CommonUse.CommonSettingsStorageSaveAndRefreshReusableValues(ObjectKey, SettingsKey, Value);
	
EndProcedure

// Saves the setting to storage of the system settings.
// 
// Parameters:
//   Correspond to
// the SystemSettingsStorage.Save method, details - see StorageSave procedure parameters().
// 
Procedure SystemSettingsStorageSave(ObjectKey, SettingsKey = "", Value, SettingsDescription = Undefined,
	UserName = Undefined, NeedToUpdateReusedValues = False) Export
	
	CommonUse.SystemSettingsStorageSave(
		ObjectKey, 
		SettingsKey, 
		Value,
		SettingsDescription, 
		UserName, 
		NeedToUpdateReusedValues);
	
EndProcedure

// Imports the setting from the storage of system settings.
//
// Parameters:
//   Correspond
//   to the SystemSettingsStorage.Import method, details - see StorageImport function parameters().
//
Function SystemSettingsStorageImport(ObjectKey, SettingsKey = "", DefaultValue = Undefined, 
	SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return CommonUse.SystemSettingsStorageImport(
		ObjectKey, 
		SettingsKey, 
		DefaultValue, 
		SettingsDescription, 
		UserName);
	
EndFunction

// Deletes the setting from the storage of the system settings.
//
// Parameters:
//   Correspond
//   to the SystemSettingsStorage.Delete method, details - see parameters of the DeleteStorage() function.
//
Procedure SystemSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	CommonUse.SystemSettingsStorageDelete(ObjectKey, SettingsKey, UserName);
	
EndProcedure

// Saves the setting to storage of form data settings.
// 
// Parameters:
//   Correspond to
// the SystemSettingsStorage.Save method, details - see StorageSave procedure parameters().
//
Procedure FormDataSettingsStorageSave(ObjectKey, SettingsKey = "", Value, SettingsDescription = Undefined,
	UserName = Undefined, NeedToUpdateReusedValues = False) Export
	
	CommonUse.FormDataSettingsStorageSave(
		ObjectKey, 
		SettingsKey, 
		Value,
		SettingsDescription, 
		UserName, 
		NeedToUpdateReusedValues);
	
EndProcedure

// Imports the setting from storage of form data settings.
//
// Parameters:
//   Correspond
//   to the SystemSettingsStorage.Import method, details - see StorageImport function parameters().
//
Function FormDataSettingsStorageImport(ObjectKey, SettingsKey = "", DefaultValue = Undefined, 
	SettingsDescription = Undefined, UserName = Undefined) Export
	
	Return CommonUse.FormDataSettingsStorageImport(
		ObjectKey, 
		SettingsKey, 
		DefaultValue, 
		SettingsDescription, 
		UserName);
	
EndFunction

// Deletes the setting from the storage of form data settings.
//
// Parameters:
//   Correspond
//   to the DataFormStorage.Delete method, details - see parameters of the DeleteStorage() function.
//
Procedure FormDataSettingsStorageDelete(ObjectKey, SettingsKey, UserName) Export
	
	CommonUse.FormDataSettingsStorageDelete(ObjectKey, SettingsKey, UserName);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Functions for work with style colors in the client code.

// Function receives the style color by the name of style item.
//
// Parameters:
// StyleColorName - String -  Name of the style item.
//
// Returns:
// Color.
//
Function StyleColor(StyleColorName) Export
	
	Return StyleColors[StyleColorName];
	
EndFunction

// Function receives the style font by the name of style item.
//
// Parameters:
// StyleFontName - String - Name of the style font.
//
// Returns:
// Font.
//
Function StyleFont(StyleFontName) Export
	
	Return StyleFonts[StyleFontName];
	
EndFunction

#EndRegion

#Region ExternalFirstLaunch

Function ThisIsFirstLaunch() Export
	
	Return Not ValueIsFilled(Constants.AccountingCurrency.Get());
	
EndFunction

Function FillDefaultFirstLaunch() Export
	
	InfobaseUpdateSB.DefaultFirstLaunch();
	
EndFunction

#EndRegion