
&AtServer
Procedure FillBaseOfGoods()
	
	Query = New Query(
	"SELECT
	|	Reg.Barcode AS Barcode,
	|	PRESENTATION(Reg.ProductsAndServices) AS ProductsAndServices,
	|	PRESENTATION(Reg.Characteristic) AS Characteristic,
	|	PRESENTATION(Reg.Batch) AS Batch
	|FROM
	|	InformationRegister.ProductsAndServicesBarcodes AS Reg
	|
	|ORDER BY
	|	Reg.Barcode");
	
	CurTable = Query.Execute().Unload();
	
	ValueToFormAttribute(CurTable, "ExportingTable");
	
EndProcedure

&AtServer
Function GetProductBaseArray()
	
	CurTable = FormAttributeToValue("ExportingTable");
	
	ArrayExportings = New Array();
	
	For Each TSRow IN CurTable Do
		StringStructure = New Structure(
			"Barcode, ProductsAndServices, MeasurementUnit, ProductsAndServicesCharacteristic, ProductsAndServicesSeries, Quality, Price, Quantity",
			TSRow.Barcode, TSRow.ProductsAndServices, TSRow.Batch, TSRow.Characteristic, "", "" , "", 0);
		ArrayExportings.Add(StringStructure);
	EndDo;
	
	Return ArrayExportings;
	
EndFunction

&AtClient
Procedure FillExecute()
	
	FillBaseOfGoods();
	
EndProcedure

&AtClient
Procedure ExportExecute()
	
	ErrorDescription = "";
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Getting product base
		DCTTable = GetProductBaseArray();
		NotificationsAtExportVTSD = New NotifyDescription("ExportVTSDEnd", ThisObject);
		EquipmentManagerClient.StartDataExportVTSD(NotificationsAtExportVTSD, UUID, DCTTable);
		
	Else
		
		MessageText = NStr("en='First, you need to select the workplace of the current session peripherals.';ru='Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportVTSDEnd(Result, Parameters) Export
	
	If Result Then
		MessageText = NStr("en='Data is successfully exported to the DCT.';ru='Данные успешно выгружены в ТСД.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure














