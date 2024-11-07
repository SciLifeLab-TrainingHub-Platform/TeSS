# lib/tasks/create_nodes.rake
# To run this task, use the command: bin/rails node:create_entries
namespace :node do
  desc "Create SciLifeLab and External entries in the Node model"
  task create_entries: :environment do
    admin_user = User.joins(:role).find_by(roles: { name: 'admin' })
    if admin_user
      # delete all the previous nodes and its association
      Node.destroy_all
      # create new nodes 
      Node.where(user: admin_user, name: Node::SCILIFE_LAB_NODE_NAME, slug: Node::SCILIFE_LAB_NODE_SLUG).first_or_create
      Node.where(user: admin_user, name: Node::EXTERNAL_NODE_NAME, slug: Node::EXTERNAL_NODE_SLUG).first_or_create
      puts "Ensured presence of nodes: #{Node::SCILIFE_LAB_NODE_NAME} and #{Node::EXTERNAL_NODE_NAME}."
    else
      puts "Admin user not found. Please ensure an admin user exists in the database."
    end
    puts "Nodes entries (SciLifeLab and External) created in the Node model."
  end
end
