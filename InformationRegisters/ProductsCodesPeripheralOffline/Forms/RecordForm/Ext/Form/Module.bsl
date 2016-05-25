
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Query = New Query(
	"SELECT TOP 1
	|	ProductsCodesPeripheralOffline.Code AS Code
	|FROM
	|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
	|WHERE
	|	ProductsCodesPeripheralOffline.Code = &Code
	|	AND ProductsCodesPeripheralOffline.ExchangeRule = &ExchangeRule
	|	AND ProductsCodesPeripheralOffline.ProductsAndServices = VALUE(Catalog.ProductsAndServices.EmptyRef)
	|");
	
	Query.SetParameter("Code", CurrentObject.Code);
	Query.SetParameter("ExchangeRule", CurrentObject.ExchangeRule);
	
	If Not Query.Execute().IsEmpty() Then
		ToRemoveWrite = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordManager();
		ToRemoveWrite.Code = CurrentObject.Code;
		ToRemoveWrite.ExchangeRule = CurrentObject.ExchangeRule;
		ToRemoveWrite.Delete();
	EndIf;
	
	Code = PeripheralsOfflineServerCall.GetMaximumCode(Record.ExchangeRule)+1;
	While Code < CurrentObject.Code Do
		PeripheralsOfflineServerCall.DeleteCode(CurrentObject.ExchangeRule, Code);
		Code = Code+1;
	EndDo;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Record.SourceRecordKey.Code <> CurrentObject.Code Then
		PeripheralsOfflineServerCall.DeleteCode(CurrentObject.ExchangeRule, Record.SourceRecordKey.Code);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	Query = New Query(
	"SELECT TOP 1
	|	ProductsCodesPeripheralOffline.Code AS Code,
	|	ProductsCodesPeripheralOffline.ProductsAndServices AS ProductsAndServices,
	|	ProductsCodesPeripheralOffline.Characteristic AS Characteristic,
	|	ProductsCodesPeripheralOffline.Batch AS Batch,
	|	ProductsCodesPeripheralOffline.MeasurementUnit AS MeasurementUnit,
	|	ProductsCodesPeripheralOffline.ProductsAndServices.Description AS ProductsAndServicesPresentation,
	|	ProductsCodesPeripheralOffline.Characteristic.Description AS CharacteristicPresentation,
	|	ProductsCodesPeripheralOffline.Batch.Description AS BatchPresentation,
	|	ProductsCodesPeripheralOffline.MeasurementUnit.Description AS MeasurementUnitPresentation
	|FROM
	|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
	|WHERE
	|	ProductsCodesPeripheralOffline.Code = &Code
	|	AND ProductsCodesPeripheralOffline.ProductsAndServices <> VALUE(Catalog.ProductsAndServices.EmptyRef)
	|");
	
	Query.SetParameter("Code", Record.Code);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() // Barcode is already written in the database
		AND Record.SourceRecordKey.Code <> Record.Code Then
		
		ErrorDescription = NStr("en='Such code is already assigned for the items %ProductsAndServices%'");
		ErrorDescription = StrReplace(ErrorDescription, "%ProductsAndServices%", """" + Selection.ProductsAndServicesPresentation + """"
						+ ?(ValueIsFilled(Selection.Characteristic), " " + NStr("en='with characteristic'") + " """ + Selection.CharacteristicPresentation + """", "")
						+ ?(ValueIsFilled(Selection.Batch), " " + NStr("en='with the batch'") + " """ + Selection.BatchPresentation + """", "")
						+ ?(ValueIsFilled(Selection.MeasurementUnit), " " + NStr("en='UOM'") + " """ + Selection.MeasurementUnitPresentation + """", ""));
		
		Message = New UserMessage;
		Message.Text = ErrorDescription;
		Message.Field = "Record.Code";
		Message.Message();
		Cancel = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CodesArray = GetFreeCodes().UnloadColumn("Code");
	Items.Code.ChoiceList.LoadValues(CodesArray);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Function GetFreeCodes()
	
	FreeCodes = PeripheralsOfflineServerCall.GetFreeCodes(Record.ExchangeRule, 20);
	NewRow = FreeCodes.Add();
	NewRow.Code = PeripheralsOfflineServerCall.GetMaximumCode(Record.ExchangeRule)+1;
	
	Return FreeCodes;
	
EndFunction






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
