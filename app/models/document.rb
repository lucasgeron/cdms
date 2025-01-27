class Document < ApplicationRecord
  include Searchable
  search_by :title

  include Members
  build_member_methods(relationship: :signers, name: :signing_member)

  belongs_to :creator_user, class_name: :User

  belongs_to :department
  has_many :document_signers, dependent: :destroy
  has_many :signers, through: :document_signers, source: :user

  has_many :document_recipients, dependent: :destroy

  enum category: { declaration: 'declaration', certification: 'certification' }, _suffix: :category

  validates :category, inclusion: { in: Document.categories.values }
  validates :title, :content, presence: true
  validates :variables, json: true

  def variables=(variables)
    variables = JSON.parse(variables) if variables.is_a?(String)
    super(variables)
  end

  def self.human_categories
    categories.each_with_object({}) do |(key, _value), obj|
      obj[I18n.t("enums.categories.#{key}")] = key
    end
  end

  def default_variables
    variables = [:name, :cpf, :email, :register_number]

    variables.map do |variable|
      { name: User.human_attribute_name(variable), identifier: variable }
    end
  end

  def recipients
    @recipients ||= Logics::Document::Recipient.new(document_recipients)
  end

  def someone_signed?
    document_signers.where(signed: true).any?
  end

  def reopen_to_edit(params = {})
    update(
      justification: params[:justification],
      last_reopened_by_user_id: params[:user_id],
      last_reopened_at: Time.current,
      reopened: true
    )
    document_signers.update(signed: false)
  end
end
