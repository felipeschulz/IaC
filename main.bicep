/* Nesse template, cria o WebApp, o ServicePlan, dá um push do WordPress lá do GitHub, Cria o MySQL Server, a database, 
bem como a regra de firewall no MySQL, e configura os hostnames do dominio personalizado */

param location string = resourceGroup().location
param webAppName string = 'azuretar${uniqueString(resourceGroup().id)}'
param MySQLServerName string = 'azuretarMySQL'
param appServicePlanName string = 'azuretarDemoWP'
param DBName string = 'azuretar'
param subDomain string = 'www'
param Domain string

@secure()
param administratorLogin string
@secure()
param administratorLoginPassword string

var charset = 'utf8'
var collation = 'utf8_general_ci'


resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'B1'
    capacity: 1
  }
  
}

resource webApp 'Microsoft.Web/sites@2020-06-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    clientAffinityEnabled:true
    httpsOnly: true
    siteConfig:{
      appSettings:[
        {
          name:'DATABASE_HOST'
          value:'P:DATABASEHOST: 3306'
        }
        {
          name:'PHPMYADMIN_EXTENSION_VERSION'
          value: 'latest'
        }
      ]
      connectionStrings:[
        {
          name:'defaultConnection'
          connectionString:'Database=${DBName};Data Source=${MySQLServerName}.mysql.database.azure.com;User Id=${administratorLogin}@${MySQLServerName};Password=${administratorLoginPassword}'
          type:'MySql'
        }
      ]
      phpVersion:'7.4'
      netFrameworkVersion:'v4.0'
    }
  }
  dependsOn:[
    mySQLdb
  ]
}

resource WordPress 'Microsoft.Web/sites/sourcecontrols@2021-02-01' ={
  name: 'web'
  parent:webApp
  properties:{
    repoUrl:'https://github.com/azureappserviceoss/wordpress-azure'
    branch:'master'
    isManualIntegration:true
  }
}

resource mySQLdb 'Microsoft.DBforMySQL/servers@2017-12-01' = {
  name: MySQLServerName
  location: location
  tags:{
    AppProfile: 'Wordpress'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    createMode: 'Default'
  }
}

resource DatabaseMySQL 'Microsoft.DBforMySQL/servers/databases@2017-12-01' = {
 name:DBName
 parent:mySQLdb
 properties:{
   charset:charset
   collation:collation
 }
}

resource FirewallRules 'Microsoft.DBforMySQL/servers/firewallRules@2017-12-01' ={
  name: 'AllowAll'
  properties:{
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
  parent:mySQLdb
}

resource hostnameBindingDefault 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = {
  parent: webApp
  name: '${subDomain}.${Domain}'
  properties: {
    siteName: webAppName
    azureResourceName: webAppName
    azureResourceType: 'Website'
    customHostNameDnsRecordType: 'CName'
    hostNameType: 'Managed'
  }
}

resource hostnameBindingAzureWebsites 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = {
  parent: webApp
  name: '${webAppName}.azurewebsites.net'
  properties: {
    siteName:webAppName
    hostNameType: 'Verified'
  }
  dependsOn:[
    hostnameBindingDefault
  ]
}
