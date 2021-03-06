# deploy

Provide fast deployment command, including watcher, ignore file and pre/post deployment scripts

`deploy`    
`deploy watch`  deploy on update, will only deploy updated files  
`deploy config`  show deploy configuration file content

## Configuration file
`deploy` hold its configuration inside a `.deploy` file with the following arguments :

- `server` your SSH credentials  
- `path` target path where to deploy current working directory  
- `user` if logged as root, rights to apply to target path  

This file is created interactively if not found

## Ignore file
You can exclude directories from deployment with `.deploy_ignore` file :
```
.deploy*
node_modules
vendor
```

## Pre and Post deployment script
You can had custom script executed before/after deployment by creating `.deploy_pre` and `.deploy_post` files

You can use deploy configuration variables inside those scripts :
- `$server`
- `$path`
- `$user`
